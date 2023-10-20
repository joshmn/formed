# frozen_string_literal: true

module Formed
  module NestedAttributes # :nodoc:
    class TooManyRecords < StandardError
    end

    extend ActiveSupport::Concern

    included do
      class_attribute :nested_attributes_options, instance_writer: false, default: {}
    end

    def associated_records_to_validate(association, new_record)
      if new_record
        association&.target
      else
        association.target
      end
    end

    # Validate the association if <tt>:validate</tt> or <tt>:autosave</tt> is
    # turned on for the association.
    def validate_single_association(reflection)
      association = association_instance_get(reflection.name)
      record      = association&.reader
      association_valid?(reflection, record) if record
    end

    # Validate the associated records if <tt>:validate</tt> or
    # <tt>:autosave</tt> is turned on for the association specified by
    # +reflection+.
    def validate_collection_association(reflection)
      return unless (association = association_instance_get(reflection.name))
      return unless (records = associated_records_to_validate(association, new_record?))

      records.each_with_index { |record, index| association_valid?(reflection, record, index) }
    end

    # Returns whether or not the association is valid and applies any errors to
    # the parent, <tt>self</tt>, if it wasn't. Skips any <tt>:autosave</tt>
    # enabled records if they're marked_for_destruction? or destroyed.
    def association_valid?(reflection, record, index = nil)
      context = nil

      unless (valid = record.valid?(context))
        indexed_attribute = !index.nil? && reflection.options[:index_errors]

        record.errors.group_by_attribute.each do |attribute, errors|
          attribute = normalize_reflection_attribute(indexed_attribute, reflection, index, attribute)

          errors.each do |error|
            self.errors.import(
              error,
              attribute: attribute
            )
          end
        end
      end
      valid
    end

    def normalize_reflection_attribute(indexed_attribute, reflection, index, attribute)
      if indexed_attribute
        "#{reflection.name}[#{index}].#{attribute}"
      else
        "#{reflection.name}.#{attribute}"
      end
    end

    def _ensure_no_duplicate_errors
      errors.uniq!
    end

    module ClassMethods
      REJECT_ALL_BLANK_PROC = proc { |attributes| attributes.all? { |key, value| key == "_destroy" || value.blank? } }

      def accepts_nested_attributes_for(*attr_names)
        options = { allow_destroy: false, update_only: false }
        options.update(attr_names.extract_options!)
        options.assert_valid_keys(:allow_destroy, :reject_if, :limit, :update_only)
        options[:reject_if] = REJECT_ALL_BLANK_PROC if options[:reject_if] == :all_blank

        attr_names.each do |association_name|
          unless (reflection = _reflect_on_association(association_name))
            raise ArgumentError, "No association found for name `#{association_name}'. Has it been defined yet?"
          end

          nested_attributes_options = self.nested_attributes_options.dup
          nested_attributes_options[association_name.to_sym] = options
          self.nested_attributes_options = nested_attributes_options
          define_validation_callbacks(reflection)

          type = (reflection.collection? ? :collection : :one_to_one)
          generate_association_writer(association_name, type)
        end
      end

      private

      def define_validation_callbacks(reflection)
        validation_method = :"validate_associated_records_for_#{reflection.name}"
        return unless reflection.validate? && !method_defined?(validation_method)

        method = if reflection.collection?
                   :validate_collection_association
                 else
                   :validate_single_association
                 end

        define_non_cyclic_method(validation_method) { send(method, reflection) }
        validate validation_method
        after_validation :_ensure_no_duplicate_errors
      end

      def define_non_cyclic_method(name, &block)
        return if method_defined?(name, false)

        define_method(name) do |*_args|
          result = true
          @_already_called ||= {}
          # Loop prevention for validation of associations
          unless @_already_called[name]
            begin
              @_already_called[name] = true
              result = instance_eval(&block)
            ensure
              @_already_called[name] = false
            end
          end

          result
        end
      end

      def generate_association_writer(association_name, type)
        generated_association_methods.module_eval <<-EORUBY, __FILE__, __LINE__ + 1
            silence_redefinition_of_method :#{association_name}_attributes=
            def #{association_name}_attributes=(attributes)
              assign_nested_attributes_for_#{type}_association(:#{association_name}, attributes)
            end
        EORUBY
      end
    end

    def _destroy
      marked_for_destruction?
    end

    private

    UNASSIGNABLE_KEYS = %w[id _destroy].freeze

    def assign_nested_attributes_for_one_to_one_association(association_name, attributes)
      options = nested_attributes_options[association_name]
      attributes = attributes.to_h if attributes.respond_to?(:permitted?)
      attributes = attributes.with_indifferent_access
      existing_record = send(association_name)

      if (options[:update_only] || !attributes["id"].blank?) && existing_record && (options[:update_only] || existing_record.id.to_s == attributes["id"].to_s)
        assign_to_or_mark_for_destruction(existing_record, attributes, options[:allow_destroy]) unless call_reject_if(
          association_name, attributes
        )

      elsif attributes["id"].present?
        raise_nested_attributes_record_not_found!(association_name, attributes["id"])

      elsif !reject_new_record?(association_name, attributes)
        assignable_attributes = attributes.except(*UNASSIGNABLE_KEYS)

        if existing_record&.new_record?
          existing_record.assign_attributes(assignable_attributes)
          association(association_name).initialize_attributes(existing_record)
        else
          method = :"build_#{association_name}"
          if respond_to?(method)
            send(method, assignable_attributes)
          else
            raise ArgumentError,
                  "Cannot build association `#{association_name}'. Are you trying to build a polymorphic one-to-one association?"
          end
        end
      end
    end

    def assign_nested_attributes_for_collection_association(association_name, attributes_collection)
      options = nested_attributes_options[association_name]
      attributes_collection = attributes_collection.to_h if attributes_collection.respond_to?(:permitted?)

      unless attributes_collection.is_a?(Hash) || attributes_collection.is_a?(Array)
        raise ArgumentError,
              "Hash or Array expected for attribute `#{association_name}`, got #{attributes_collection.class.name} (#{attributes_collection.inspect})"
      end

      if attributes_collection.is_a? Hash
        keys = attributes_collection.keys
        attributes_collection = if keys.include?("id") || keys.include?(:id)
                                  [attributes_collection]
                                else
                                  attributes_collection.values
                                end
      end

      association = association(association_name)

      if association.loaded?
        association.target
      else
        attributes_collection
      end

      attributes_collection.each do |attributes|
        attributes = attributes.to_h if attributes.respond_to?(:permitted?)
        attributes = attributes.with_indifferent_access

        if attributes["id"].blank?
          unless reject_new_record?(association_name, attributes)
            association.reader.build(attributes.except(*UNASSIGNABLE_KEYS))
          end
        else
          unless call_reject_if(association_name, attributes)

            target_record = association.target.detect { |record| record.id.to_s == attributes["id"].to_s }
            if target_record
              existing_record = association.reader.build(attributes.except(*UNASSIGNABLE_KEYS))
            else
              existing_record = association.reader.build(attributes)
              association.add_to_target(existing_record, skip_callbacks: true)
            end

            assign_to_or_mark_for_destruction(existing_record, attributes, options[:allow_destroy])
          end
        end
      end
    end

    # Updates a record with the +attributes+ or marks it for destruction if
    # +allow_destroy+ is +true+ and has_destroy_flag? returns +true+.
    def assign_to_or_mark_for_destruction(record, attributes, allow_destroy)
      record.assign_attributes(attributes)
      record.mark_for_destruction if has_destroy_flag?(attributes) && allow_destroy
    end

    # Determines if a hash contains a truthy _destroy key.
    def has_destroy_flag?(hash)
      ::ActiveModel::Type::Boolean.new.cast(hash["destroy"])
    end

    # Determines if a new record should be rejected by checking
    # has_destroy_flag? or if a <tt>:reject_if</tt> proc exists for this
    # association and evaluates to +true+.
    def reject_new_record?(association_name, attributes)
      will_be_destroyed?(association_name, attributes) || call_reject_if(association_name, attributes)
    end

    # Determines if a record with the particular +attributes+ should be
    # rejected by calling the reject_if Symbol or Proc (if defined).
    # The reject_if option is defined by +accepts_nested_attributes_for+.
    #
    # Returns false if there is a +destroy_flag+ on the attributes.
    def call_reject_if(association_name, attributes)
      return false if will_be_destroyed?(association_name, attributes)

      case callback = nested_attributes_options[association_name][:reject_if]
      when Symbol
        method(callback).arity.zero? ? send(callback) : send(callback, attributes)
      when Proc
        callback.call(attributes)
      end
    end

    # Only take into account the destroy flag if <tt>:allow_destroy</tt> is true
    def will_be_destroyed?(association_name, attributes)
      allow_destroy?(association_name) && has_destroy_flag?(attributes)
    end

    def allow_destroy?(association_name)
      nested_attributes_options[association_name][:allow_destroy]
    end

    def raise_nested_attributes_record_not_found!(association_name, record_id)
      model = self.class._reflect_on_association(association_name).klass.name
      raise RecordNotFound.new("Couldn't find #{model} with ID=#{record_id} for #{self.class.name} with ID=#{id}",
                               model, "id", record_id)
    end
  end
end

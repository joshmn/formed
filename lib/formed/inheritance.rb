# frozen_string_literal: true

module Formed
  module Inheritance
    extend ActiveSupport::Concern

    included do
      class_attribute :store_full_class_name, instance_writer: false, default: true

      set_base_class
    end

    module ClassMethods
      # Determines if one of the attributes passed in is the inheritance column,
      # and if the inheritance column is attr accessible, it initializes an
      # instance of the given subclass instead of the base class.
      def new(attributes = nil, &block)
        if abstract_class? || self == Formed
          raise NotImplementedError, "#{self} is an abstract class and cannot be instantiated."
        end

        if _has_attribute?(inheritance_column)
          subclass = subclass_from_attributes(attributes)

          if subclass.nil? && (scope_attributes = current_scope&.scope_for_create)
            subclass = subclass_from_attributes(scope_attributes)
          end

          subclass = subclass_from_attributes(column_defaults) if subclass.nil? && base_class?
        end

        if subclass && subclass != self
          subclass.new(attributes, &block)
        else
          super
        end
      end

      # Returns the class descending directly from ActiveRecord::Base, or
      # an abstract class, if any, in the inheritance hierarchy.
      #
      # If A extends ActiveRecord::Base, A.base_class will return A. If B descends from A
      # through some arbitrarily deep hierarchy, B.base_class will return A.
      #
      # If B < A and C < B and if A is an abstract_class then both B.base_class
      # and C.base_class would return B as the answer since A is an abstract_class.
      attr_reader :base_class

      # Returns whether the class is a base class.
      # See #base_class for more information.
      def base_class?
        base_class == self
      end

      attr_accessor :abstract_class

      def abstract_class?
        defined?(@abstract_class) && @abstract_class == true
      end

      def primary_abstract_class; end

      def inherited(subclass)
        subclass.set_base_class
        subclass.instance_variable_set(:@_type_candidates_cache, Concurrent::Map.new)
        super
      end

      def dup # :nodoc:
        # `initialize_dup` / `initialize_copy` don't work when defined
        # in the `singleton_class`.
        other = super
        other.set_base_class
        other
      end

      def initialize_clone(other) # :nodoc:
        super
        set_base_class
      end

      protected

      # Returns the class type of the record using the current module as a prefix. So descendants of
      # MyApp::Business::Account would appear as MyApp::Business::AccountSubclass.
      def compute_type(type_name)
        if type_name.start_with?("::")
          # If the type is prefixed with a scope operator then we assume that
          # the type_name is an absolute reference.
          type_name.constantize
        else

          type_candidate = @_type_candidates_cache[type_name]
          if type_candidate && (type_constant = type_candidate.safe_constantize)
            return type_constant
          end

          # Build a list of candidates to search for
          candidates = []
          name.scan(/::|$/) { candidates.unshift "#{::Regexp.last_match.pre_match}::#{type_name}" }
          candidates << type_name
          form_candidates = []
          candidates.each do |candidate|
            next if candidate.end_with?("Form")

            form_candidates << "#{candidate}Form"
          end

          candidates += form_candidates

          candidates.each do |candidate|
            constant = candidate.safe_constantize
            if candidate == constant.to_s
              @_type_candidates_cache[type_name] = candidate
              return constant
            end
          end

          raise NameError.new("uninitialized constant #{candidates.first}", candidates.first)
        end
      end

      def set_base_class # :nodoc:
        @base_class = if self == Formed::Base
                        self
                      else
                        unless self < Formed::Base
                          raise FormedError, "#{name} doesn't belong in a hierarchy descending from Formed"
                        end

                        if superclass == Formed || superclass.abstract_class?
                          self
                        else
                          superclass.base_class
                        end
                      end
      end

      private

      # Detect the subclass from the inheritance column of attrs. If the inheritance column value
      # is not self or a valid subclass, raises ActiveRecord::SubclassNotFound
      def subclass_from_attributes(attrs)
        attrs = attrs.to_h if attrs.respond_to?(:permitted?)
        return unless attrs.is_a?(Hash)

        subclass_name = attrs[inheritance_column] || attrs[inheritance_column.to_sym]

        return unless subclass_name.present?

        find_sti_class(subclass_name)
      end
    end

    def initialize_dup(other)
      super
      ensure_proper_type
    end

    private

    def initialize_internals_callback
      super
      ensure_proper_type
    end

    # Sets the attribute used for single table inheritance to this class name if this is not the
    # ActiveRecord::Base descendant.
    # Considering the hierarchy Reply < Message < ActiveRecord::Base, this makes it possible to
    # do Reply.new without having to set <tt>Reply[Reply.inheritance_column] = "Reply"</tt> yourself.
    # No such attribute would be set for objects of the Message class in that example.
    def ensure_proper_type
      klass = self.class
      return unless klass.finder_needs_type_condition?

      _write_attribute(klass.inheritance_column, klass.sti_name)
    end
  end
end

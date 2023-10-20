# frozen_string_literal: true

module Formed
  module Reflection # :nodoc:
    extend ActiveSupport::Concern

    included do
      class_attribute :_reflections, instance_writer: false, default: {}
      class_attribute :aggregate_reflections, instance_writer: false, default: {}
      class_attribute :automatic_scope_inversing, instance_writer: false, default: false
    end

    class << self
      def create(macro, name, scope, options, ar)
        reflection = reflection_class_for(macro).new(name, scope, options, ar)
        options[:through] ? ThroughReflection.new(reflection) : reflection
      end

      def add_reflection(ar, name, reflection)
        ar.clear_reflections_cache
        name = -name.to_s
        ar._reflections = ar._reflections.except(name).merge!(name => reflection)
      end

      def add_aggregate_reflection(ar, name, reflection)
        ar.aggregate_reflections = ar.aggregate_reflections.merge(-name.to_s => reflection)
      end

      private

      def reflection_class_for(macro)
        case macro
        when :composed_of
          AggregateReflection
        when :has_many
          HasManyReflection
        when :has_one
          HasOneReflection
        when :belongs_to
          BelongsToReflection
        else
          raise "Unsupported Macro: #{macro}"
        end
      end
    end

    # \Reflection enables the ability to examine the associations and aggregations of
    # Active Record classes and objects. This information, for example,
    # can be used in a form builder that takes an Active Record object
    # and creates input fields for all of the attributes depending on their type
    # and displays the associations to other objects.
    #
    # MacroReflection class has info for AggregateReflection and AssociationReflection
    # classes.
    module ClassMethods
      # Returns an array of AggregateReflection objects for all the aggregations in the class.
      def reflect_on_all_aggregations
        aggregate_reflections.values
      end

      # Returns the AggregateReflection object for the named +aggregation+ (use the symbol).
      #
      #   Account.reflect_on_aggregation(:balance) # => the balance AggregateReflection
      #
      def reflect_on_aggregation(aggregation)
        aggregate_reflections[aggregation.to_s]
      end

      # Returns a Hash of name of the reflection as the key and an AssociationReflection as the value.
      #
      #   Account.reflections # => {"balance" => AggregateReflection}
      #
      def reflections
        @reflections ||= begin
          ref = {}

          _reflections.each do |name, reflection|
            parent_reflection = reflection.parent_reflection

            if parent_reflection
              parent_name = parent_reflection.name
              ref[parent_name.to_s] = parent_reflection
            else
              ref[name] = reflection
            end
          end

          ref
        end
      end

      # Returns an array of AssociationReflection objects for all the
      # associations in the class. If you only want to reflect on a certain
      # association type, pass in the symbol (<tt>:has_many</tt>, <tt>:has_one</tt>,
      # <tt>:belongs_to</tt>) as the first parameter.
      #
      # Example:
      #
      #   Account.reflect_on_all_associations             # returns an array of all associations
      #   Account.reflect_on_all_associations(:has_many)  # returns an array of all has_many associations
      #
      def reflect_on_all_associations(macro = nil)
        association_reflections = reflections.values
        association_reflections.select! { |reflection| reflection.macro == macro } if macro
        association_reflections
      end

      # Returns the AssociationReflection object for the +association+ (use the symbol).
      #
      #   Account.reflect_on_association(:owner)             # returns the owner AssociationReflection
      #   Invoice.reflect_on_association(:line_items).macro  # returns :has_many
      #
      def reflect_on_association(association)
        reflections[association.to_s]
      end

      def _reflect_on_association(association) # :nodoc:
        _reflections[association.to_s]
      end

      # Returns an array of AssociationReflection objects for all associations which have <tt>:autosave</tt> enabled.
      def reflect_on_all_autosave_associations
        reflections.values.select { |reflection| reflection.options[:autosave] }
      end

      def clear_reflections_cache # :nodoc:
        @__reflections = nil
      end
    end

    # Holds all the methods that are shared between MacroReflection and ThroughReflection.
    #
    #   AbstractReflection
    #     MacroReflection
    #       AggregateReflection
    #       AssociationReflection
    #         HasManyReflection
    #         HasOneReflection
    #         BelongsToReflection
    #         HasAndBelongsToManyReflection
    #     ThroughReflection
    #     PolymorphicReflection
    #     RuntimeReflection
    class AbstractReflection # :nodoc:
      def through_reflection?
        false
      end

      def table_name
        klass.table_name
      end

      # Returns a new, unsaved instance of the associated class. +attributes+ will
      # be passed to the class's constructor.
      def build_association(attributes, &block)
        klass.new(attributes, &block)
      end

      # Returns the class name for the macro.
      #
      # <tt>composed_of :balance, class_name: 'Money'</tt> returns <tt>'Money'</tt>
      # <tt>has_many :clients</tt> returns <tt>'Client'</tt>
      def class_name
        @class_name ||= -(options[:class_name] || derive_class_name).to_s
      end

      # Returns a list of scopes that should be applied for this Reflection
      # object when querying the database.
      def scopes
        []
      end

      def constraints
        chain.flat_map(&:scopes)
      end

      def inverse_of
        return unless inverse_name

        @inverse_of ||= klass._reflect_on_association inverse_name
      end

      def check_validity_of_inverse!
        return if polymorphic?
        raise InverseOfAssociationNotFoundError, self if has_inverse? && inverse_of.nil?
        raise InverseOfAssociationRecursiveError, self if has_inverse? && inverse_of == self
      end

      def alias_candidate(name)
        "#{plural_name}_#{name}"
      end

      def chain
        collect_join_chain
      end

      def build_scope(table, predicate_builder = predicate_builder(table), klass = self.klass)
        Relation.create(
          klass,
          table: table,
          predicate_builder: predicate_builder
        )
      end

      def strict_loading?
        options[:strict_loading]
      end

      def strict_loading_violation_message(owner)
        message = +"`#{owner}` is marked for strict_loading."
        message << " The #{polymorphic? ? "polymorphic association" : "#{klass} association"}"
        message << " named `:#{name}` cannot be lazily loaded."
      end

      protected

      # FIXME: this is a horrible name
      def actual_source_reflection
        self
      end

      private

      def predicate_builder(table)
        PredicateBuilder.new(TableMetadata.new(klass, table))
      end

      def primary_key(klass)
        klass.primary_key || raise(UnknownPrimaryKey, klass)
      end

      def ensure_option_not_given_as_class!(option_name)
        return unless options[option_name].instance_of?(Class)

        raise ArgumentError, "A class was passed to `:#{option_name}` but we are expecting a string."
      end
    end

    # Base class for AggregateReflection and AssociationReflection. Objects of
    # AggregateReflection and AssociationReflection are returned by the Reflection::ClassMethods.
    class MacroReflection < AbstractReflection
      # Returns the name of the macro.
      #
      # <tt>composed_of :balance, class_name: 'Money'</tt> returns <tt>:balance</tt>
      # <tt>has_many :clients</tt> returns <tt>:clients</tt>
      attr_reader :name

      attr_reader :scope, :active_form, :plural_name

      # Returns the hash of options used for the macro.
      #
      # <tt>composed_of :balance, class_name: 'Money'</tt> returns <tt>{ class_name: "Money" }</tt>
      # <tt>has_many :clients</tt> returns <tt>{}</tt>
      attr_reader :options # :nodoc:

      def initialize(name, scope, options, active_form)
        @name          = name
        @scope         = scope
        @options       = options
        @active_form = active_form
        @klass         = options[:anonymous_class]
      end

      def autosave=(autosave)
        @options[:autosave] = autosave
        parent_reflection = self.parent_reflection
        parent_reflection.autosave = autosave if parent_reflection
      end

      # Returns the class for the macro.
      #
      # <tt>composed_of :balance, class_name: 'Money'</tt> returns the Money class
      # <tt>has_many :clients</tt> returns the Client class
      #
      #   class Company < ActiveRecord::Base
      #     has_many :clients
      #   end
      #
      #   Company.reflect_on_association(:clients).klass
      #   # => Client
      #
      # <b>Note:</b> Do not call +klass.new+ or +klass.create+ to instantiate
      # a new association object. Use +build_association+ or +create_association+
      # instead. This allows plugins to hook into association object creation.
      def klass
        @klass ||= compute_class(class_name)
      end

      def compute_class(name)
        name.constantize
      end

      # Returns +true+ if +self+ and +other_aggregation+ have the same +name+ attribute, +active_form+ attribute,
      # and +other_aggregation+ has an options hash assigned to it.
      def ==(other)
        super ||
          other.is_a?(self.class) &&
            name == other.name &&
            !other.options.nil? &&
            active_form == other.active_form
      end

      def scope_for(relation, owner = nil)
        relation.instance_exec(owner, &scope) || relation
      end

      private

      def derive_class_name
        "#{name.to_s.camelize}Form"
      end
    end

    # Holds all the metadata about an aggregation as it was specified in the
    # Active Record class.
    class AggregateReflection < MacroReflection # :nodoc:
      def mapping
        mapping = options[:mapping] || [name, name]
        mapping.first.is_a?(Array) ? mapping : [mapping]
      end
    end

    # Holds all the metadata about an association as it was specified in the
    # Active Record class.
    class AssociationReflection < MacroReflection # :nodoc:
      def compute_class(name)
        raise ArgumentError, "Polymorphic associations do not support computing the class." if polymorphic?

        msg = <<-MSG.squish
          Formed couldn't find a valid form for #{name} association.
          Please provide the :class_name option on the association declaration.
          If :class_name is already provided, make sure it's an Formed::Base subclass.
        MSG

        begin
          klass = active_form.send(:compute_type, name)

          raise ArgumentError, msg unless klass < Formed::Base

          klass
        rescue NameError
          raise NameError, msg
        end
      end

      attr_reader :type, :foreign_type
      attr_accessor :parent_reflection # Reflection

      def initialize(name, scope, options, active_form)
        super
        @type = -(options[:foreign_type].to_s || "#{options[:as]}_type") if options[:as]
        @foreign_type = -(options[:foreign_type].to_s || "#{name}_type") if options[:polymorphic]

        ensure_option_not_given_as_class!(:class_name)
      end

      def join_table
        @join_table ||= -(options[:join_table].to_s || derive_join_table)
      end

      def foreign_key
        @foreign_key ||= -(options[:foreign_key].to_s || derive_foreign_key)
      end

      def association_foreign_key
        @association_foreign_key ||= -(options[:association_foreign_key].to_s || class_name.foreign_key)
      end

      def association_primary_key(klass = nil)
        primary_key(klass || self.klass)
      end

      def check_validity!
        check_validity_of_inverse!
      end

      def check_eager_loadable!
        return unless scope

        return if scope.arity.zero?

        raise ArgumentError, <<-MSG.squish
            The association scope '#{name}' is instance dependent (the scope
            block takes an argument). Eager loading instance dependent scopes
            is not supported.
        MSG
      end

      def through_reflection
        nil
      end

      def source_reflection
        self
      end

      # A chain of reflections from this one back to the owner. For more see the explanation in
      # ThroughReflection.
      def collect_join_chain
        [self]
      end

      def nested?
        false
      end

      def has_scope?
        scope
      end

      def has_inverse?
        inverse_name
      end

      def polymorphic_inverse_of(associated_class)
        return unless has_inverse?
        unless (inverse_relationship = associated_class._reflect_on_association(options[:inverse_of]))
          raise InverseOfAssociationNotFoundError.new(self, associated_class)
        end

        inverse_relationship
      end

      # Returns the macro type.
      #
      # <tt>has_many :clients</tt> returns <tt>:has_many</tt>
      def macro
        raise NotImplementedError
      end

      # Returns whether or not this association reflection is for a collection
      # association. Returns +true+ if the +macro+ is either +has_many+ or
      # +has_and_belongs_to_many+, +false+ otherwise.
      def collection?
        false
      end

      # Returns whether or not the association should be validated as part of
      # the parent's validation.
      #
      # Unless you explicitly disable validation with
      # <tt>validate: false</tt>, validation will take place when:
      #
      # * you explicitly enable validation; <tt>validate: true</tt>
      # * you use autosave; <tt>autosave: true</tt>
      # * the association is a +has_many+ association
      def validate?
        !options[:validate].nil? ? options[:validate] : (options[:autosave] == true || collection?)
      end

      # Returns +true+ if +self+ is a +belongs_to+ reflection.
      def belongs_to?
        false
      end

      # Returns +true+ if +self+ is a +has_one+ reflection.
      def has_one?
        false
      end

      def association_class
        raise NotImplementedError
      end

      def polymorphic?
        options[:polymorphic]
      end

      def add_as_source(seed)
        seed
      end

      def add_as_polymorphic_through(reflection, seed)
        seed + [PolymorphicReflection.new(self, reflection)]
      end

      def add_as_through(seed)
        seed + [self]
      end

      def extensions
        Array(options[:extend])
      end

      private

      # Attempts to find the inverse association name automatically.
      # If it cannot find a suitable inverse association name, it returns
      # +nil+.
      def inverse_name
        @inverse_name = options.fetch(:inverse_of) { automatic_inverse_of } unless defined?(@inverse_name)

        @inverse_name
      end

      # returns either +nil+ or the inverse association name that it finds.
      def automatic_inverse_of
        return unless can_find_inverse_of_automatically?(self)

        inverse_name = ActiveSupport::Inflector.underscore(options[:as] || active_form.name.demodulize).to_sym

        begin
          reflection = klass._reflect_on_association(inverse_name)
        rescue NameError
          # Give up: we couldn't compute the klass type so we won't be able
          # to find any associations either.
          reflection = false
        end

        inverse_name if valid_inverse_reflection?(reflection)
      end

      # Checks if the inverse reflection that is returned from the
      # +automatic_inverse_of+ method is a valid reflection. We must
      # make sure that the reflection's active_record name matches up
      # with the current reflection's klass name.
      def valid_inverse_reflection?(reflection)
        reflection &&
          reflection != self &&
          foreign_key == reflection.foreign_key &&
          klass <= reflection.active_record &&
          can_find_inverse_of_automatically?(reflection, true)
      end

      # Checks to see if the reflection doesn't have any options that prevent
      # us from being able to guess the inverse automatically. First, the
      # <tt>inverse_of</tt> option cannot be set to false. Second, we must
      # have <tt>has_many</tt>, <tt>has_one</tt>, <tt>belongs_to</tt> associations.
      # Third, we must not have options such as <tt>:foreign_key</tt>
      # which prevent us from correctly guessing the inverse association.
      def can_find_inverse_of_automatically?(reflection, inverse_reflection = false)
        reflection.options[:inverse_of] != false &&
          !reflection.options[:through] &&
          scope_allows_automatic_inverse_of?(reflection, inverse_reflection)
      end

      # Scopes on the potential inverse reflection prevent automatic
      # <tt>inverse_of</tt>, since the scope could exclude the owner record
      # we would inverse from. Scopes on the reflection itself allow for
      # automatic <tt>inverse_of</tt> as long as
      # <tt>config.active_record.automatic_scope_inversing<tt> is set to
      # +true+ (the default for new applications).
      def scope_allows_automatic_inverse_of?(reflection, inverse_reflection)
        if inverse_reflection
          !reflection.scope
        else
          !reflection.scope || reflection.klass.automatic_scope_inversing
        end
      end

      def derive_class_name
        class_name = name.to_s
        class_name = class_name.singularize if collection?
        class_name.camelize
      end

      def derive_foreign_key
        if belongs_to?
          "#{name}_id"
        elsif options[:as]
          "#{options[:as]}_id"
        else
          active_form.model_name.to_s.foreign_key
        end
      end

      def derive_join_table
        ModelSchema.derive_join_table_name active_form.table_name, klass.table_name
      end
    end

    class HasManyReflection < AssociationReflection # :nodoc:
      def macro
        :has_many
      end

      def collection?
        true
      end

      def association_class
        if options[:through]
          Associations::HasManyThroughAssociation
        else
          Associations::HasManyAssociation
        end
      end
    end

    class HasOneReflection < AssociationReflection # :nodoc:
      def macro
        :has_one
      end

      def has_one?
        true
      end

      def association_class
        if options[:through]
          Associations::HasOneThroughAssociation
        else
          Associations::HasOneAssociation
        end
      end
    end

    class BelongsToReflection < AssociationReflection # :nodoc:
      def macro
        :belongs_to
      end

      def belongs_to?
        true
      end

      def association_class
        if polymorphic?
          Associations::BelongsToPolymorphicAssociation
        else
          Associations::BelongsToAssociation
        end
      end

      # klass option is necessary to support loading polymorphic associations
      def association_primary_key(klass = nil)
        if (primary_key = options[:primary_key])
          @association_primary_key ||= -primary_key.to_s
        else
          primary_key(klass || self.klass)
        end
      end

      private

      def can_find_inverse_of_automatically?(*)
        !polymorphic? && super
      end
    end

    class HasAndBelongsToManyReflection < AssociationReflection # :nodoc:
      def macro
        :has_and_belongs_to_many
      end

      def collection?
        true
      end
    end

    # Holds all the metadata about a :through association as it was specified
    # in the Active Record class.
    class ThroughReflection < AbstractReflection # :nodoc:
      delegate :foreign_key, :foreign_type, :association_foreign_key, :join_id_for, :type,
               :active_record_primary_key, :join_foreign_key, to: :source_reflection

      def initialize(delegate_reflection)
        @delegate_reflection = delegate_reflection
        @klass = delegate_reflection.options[:anonymous_class]
        @source_reflection_name = delegate_reflection.options[:source]

        ensure_option_not_given_as_class!(:source_type)
      end

      def through_reflection?
        true
      end

      def klass
        @klass ||= delegate_reflection.compute_class(class_name)
      end

      # Gets an array of possible <tt>:through</tt> source reflection names in both singular and plural form.
      #
      #   class Post < ActiveRecord::Base
      #     has_many :taggings
      #     has_many :tags, through: :taggings
      #   end
      #
      #   tags_reflection = Post.reflect_on_association(:tags)
      #   tags_reflection.source_reflection_names
      #   # => [:tag, :tags]
      #
      def source_reflection_names
        options[:source] ? [options[:source]] : [name.to_s.singularize, name].uniq
      end

      def check_validity!
        raise HasManyThroughAssociationNotFoundError.new(active_record, self) if through_reflection.nil?

        if through_reflection.polymorphic?
          raise HasOneAssociationPolymorphicThroughError.new(active_record.name, self) if has_one?

          raise HasManyThroughAssociationPolymorphicThroughError.new(active_record.name, self)

        end

        raise HasManyThroughSourceAssociationNotFoundError, self if source_reflection.nil?

        if options[:source_type] && !source_reflection.polymorphic?
          raise HasManyThroughAssociationPointlessSourceTypeError.new(active_record.name, self, source_reflection)
        end

        if source_reflection.polymorphic? && options[:source_type].nil?
          raise HasManyThroughAssociationPolymorphicSourceError.new(active_record.name, self, source_reflection)
        end

        if has_one? && through_reflection.collection?
          raise HasOneThroughCantAssociateThroughCollection.new(active_record.name, self, through_reflection)
        end

        if parent_reflection.nil?
          reflections = active_record.reflections.keys.map(&:to_sym)

          if reflections.index(through_reflection.name) > reflections.index(name)
            raise HasManyThroughOrderError.new(active_record.name, self, through_reflection)
          end
        end

        check_validity_of_inverse!
      end

      private

      attr_reader :delegate_reflection

      def inverse_name
        delegate_reflection.send(:inverse_name)
      end

      def derive_class_name
        # get the class_name of the belongs_to association of the through reflection
        options[:source_type] || source_reflection.class_name
      end

      delegate_methods = AssociationReflection.public_instance_methods -
                         public_instance_methods

      delegate(*delegate_methods, to: :delegate_reflection)
    end

    class PolymorphicReflection < AbstractReflection # :nodoc:
      delegate :klass, :scope, :plural_name, :type, :join_primary_key, :join_foreign_key,
               :name, :scope_for, to: :@reflection

      def initialize(reflection, previous_reflection)
        @reflection = reflection
        @previous_reflection = previous_reflection
      end

      def constraints
        @reflection.constraints + [source_type_scope]
      end
    end

    class RuntimeReflection < AbstractReflection # :nodoc:
      delegate :scope, :type, :constraints, :join_foreign_key, to: :@reflection

      def initialize(reflection, association)
        @reflection = reflection
        @association = association
      end

      def klass
        @association.klass
      end

      def aliased_table
        klass.arel_table
      end

      def join_primary_key(klass = self.klass)
        @reflection.join_primary_key(klass)
      end

      def all_includes
        yield
      end
    end
  end
end

# frozen_string_literal: true

module Formed
  module Associations
    extend ActiveSupport::Concern

    def association(name) # :nodoc:
      association = association_instance_get(name)

      if association.nil?
        unless (reflection = self.class._reflect_on_association(name))
          raise AssociationNotFoundError.new(self, name)
        end

        association = reflection.association_class.new(self, reflection)
        association_instance_set(name, association)
      end

      association
    end

    def association_cached?(name) # :nodoc:
      @association_cache.key?(name)
    end

    def initialize_dup(*) # :nodoc:
      @association_cache = {}
      super
    end

    private

    def init_internals
      @association_cache = {}
      super
    end

    # Returns the specified association instance if it exists, +nil+ otherwise.
    def association_instance_get(name)
      @association_cache[name]
    end

    # Set the specified association instance.
    def association_instance_set(name, association)
      @association_cache[name] = association
    end

    class_methods do
      def has_many(name, scope = nil, **options, &extension)
        reflection = Builder::HasMany.build(self, name, scope, options, &extension)
        Reflection.add_reflection self, name, reflection
        accepts_nested_attributes_for name
      end

      def has_one(name, scope = nil, **options)
        reflection = Builder::HasOne.build(self, name, scope, options)
        Reflection.add_reflection self, name, reflection
        accepts_nested_attributes_for name
      end
    end
  end
end

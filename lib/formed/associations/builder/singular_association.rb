# frozen_string_literal: true

module Formed
  module Associations
    module Builder
      class SingularAssociation < ::Formed::Associations::Builder::Association # :nodoc:
        def self.valid_options(options)
          super + %i[required touch]
        end

        def self.define_accessors(model, reflection)
          super
          mixin = model.generated_association_methods
          name = reflection.name

          define_constructors(mixin, name) unless reflection.polymorphic?

          mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def reload_#{name}
          association(:#{name}).force_reload_reader
        end
          CODE
        end

        # Defines the (build|create)_association methods for belongs_to or has_one association
        def self.define_constructors(mixin, name)
          mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def build_#{name}(*args, &block)
          association(:#{name}).build(*args, &block)
        end

        def create_#{name}(*args, &block)
          association(:#{name}).create(*args, &block)
        end

        def create_#{name}!(*args, &block)
          association(:#{name}).create!(*args, &block)
        end
          CODE
        end

        private_class_method :valid_options, :define_accessors, :define_constructors
      end
    end
  end
end

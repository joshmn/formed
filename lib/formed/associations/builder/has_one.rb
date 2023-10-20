# frozen_string_literal: true

module Formed
  module Associations
    module Builder
      class HasOne < SingularAssociation # :nodoc:
        def self.macro
          :has_one
        end

        def self.valid_options(options)
          valid = super
          valid += [:as] if options[:as]
          valid += %i[through source source_type] if options[:through]
          valid
        end

        def self.valid_dependent_options
          []
        end

        def self.define_callbacks(model, reflection)
          super
          add_touch_callbacks(model, reflection) if reflection.options[:touch]
        end

        def self.define_validations(model, reflection)
          super
          return unless reflection.options[:required]

          model.validates_presence_of reflection.name, message: :required
          model.validate :"ensure_#{reflection.name}_valid!"

          model.define_method "ensure_#{reflection.name}_valid!" do
            errors.add(reflection.name, :invalid) unless public_send(reflection.name).valid?
          end
        end

        private_class_method :macro, :valid_options, :valid_dependent_options,
                             :define_callbacks, :define_validations
      end
    end
  end
end

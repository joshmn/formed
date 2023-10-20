# frozen_string_literal: true

module Formed
  module Associations
    module Builder
      class CollectionAssociation < ::Formed::Associations::Builder::Association # :nodoc:
        CALLBACKS = %i[before_add after_add before_remove after_remove].freeze

        def self.valid_options(options)
          super + %i[before_add after_add before_remove after_remove extend]
        end

        def self.define_callbacks(model, reflection)
          super
          name    = reflection.name
          options = reflection.options
          CALLBACKS.each do |callback_name|
            define_callback(model, callback_name, name, options)
          end
        end

        def self.define_extensions(model, name, &block)
          return unless block_given?

          extension_module_name = "#{name.to_s.camelize}AssociationExtension"
          extension = Module.new(&block)
          model.const_set(extension_module_name, extension)
        end

        def self.define_callback(model, callback_name, name, options)
          full_callback_name = "#{callback_name}_for_#{name}"

          callback_values = Array(options[callback_name.to_sym])
          method_defined = model.respond_to?(full_callback_name)

          # If there are no callbacks, we must also check if a superclass had
          # previously defined this association
          return if callback_values.empty? && !method_defined

          unless method_defined
            model.class_attribute(full_callback_name, instance_accessor: false, instance_predicate: false)
          end

          callbacks = callback_values.map do |callback|
            case callback
            when Symbol
              ->(_method, owner, record) { owner.send(callback, record) }
            when Proc
              ->(_method, owner, record) { callback.call(owner, record) }
            else
              ->(method, owner, record) { callback.send(method, owner, record) }
            end
          end
          model.send "#{full_callback_name}=", callbacks
        end

        def self.define_writers(mixin, name)
          super

          mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name.to_s.singularize}_ids=(ids)
          association(:#{name}).ids_writer(ids)
        end
          CODE
        end

        private_class_method :valid_options, :define_callback, :define_extensions, :define_readers, :define_writers
      end
    end
  end
end

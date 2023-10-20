# frozen_string_literal: true

module Formed
  module Associations
    module Builder
      class Association
        class << self
          attr_accessor :extensions
        end
        self.extensions = []

        VALID_OPTIONS = %i[
          class_name anonymous_class primary_key foreign_key validate inverse_of
        ].freeze # :nodoc:

        def self.build(model, name, scope, options, &block)
          reflection = create_reflection(model, name, scope, options, &block)
          define_accessors model, reflection
          define_callbacks model, reflection
          define_validations model, reflection
          define_change_tracking_methods model, reflection
          reflection
        end

        def self.create_reflection(model, name, scope, options, &block)
          raise ArgumentError, "association names must be a Symbol" unless name.is_a?(Symbol)

          validate_options(options)

          extension = define_extensions(model, name, &block)
          options[:extend] = [*options[:extend], extension] if extension

          scope = build_scope(scope)

          Reflection.create(macro, name, scope, options, model)
        end

        def self.build_scope(scope)
          if scope&.arity&.zero?
            proc { instance_exec(&scope) }
          else
            scope
          end
        end

        def self.macro
          raise NotImplementedError
        end

        def self.valid_options(_options)
          VALID_OPTIONS + Association.extensions.flat_map(&:valid_options)
        end

        def self.validate_options(options)
          options.assert_valid_keys(valid_options(options))
        end

        def self.define_extensions(model, name); end

        def self.define_callbacks(model, reflection)
          Association.extensions.each do |extension|
            extension.build model, reflection
          end
        end

        # Defines the setter and getter methods for the association
        # class Post < ActiveRecord::Base
        #   has_many :comments
        # end
        #
        # Post.first.comments and Post.first.comments= methods are defined by this method...
        def self.define_accessors(model, reflection)
          mixin = model.generated_association_methods
          name = reflection.name
          define_readers(mixin, name)
          define_writers(mixin, name)
        end

        def self.define_readers(mixin, name)
          mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}
          association(:#{name}).reader
        end
          CODE
        end

        def self.define_writers(mixin, name)
          mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}=(value)
          association(:#{name}).writer(value)
        end
          CODE
        end

        def self.define_validations(model, reflection)
          # noop
        end

        def self.define_change_tracking_methods(model, reflection)
          # noop
        end

        def self.valid_dependent_options
          raise NotImplementedError
        end

        private_class_method :build_scope, :macro, :valid_options, :validate_options, :define_extensions,
                             :define_callbacks, :define_accessors, :define_readers, :define_writers, :define_validations,
                             :define_change_tracking_methods, :valid_dependent_options
      end
    end
  end
end

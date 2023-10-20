# frozen_string_literal: true

module Formed
  module Associations
    module Builder
      class HasMany < ::Formed::Associations::Builder::CollectionAssociation # :nodoc:
        def self.macro
          :has_many
        end

        def self.valid_options(options)
          valid = super
          valid += [:as] if options[:as]
          valid += %i[through source source_type] if options[:through]
          valid
        end

        def self.valid_dependent_options; end

        private_class_method :macro, :valid_options, :valid_dependent_options
      end
    end
  end
end

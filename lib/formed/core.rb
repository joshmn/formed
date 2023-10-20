# frozen_string_literal: true

module Formed
  module Core
    extend ActiveSupport::Concern

    module ClassMethods
      def inherited(child_class) # :nodoc:
        # initialize cache at class definition for thread safety
        unless child_class.base_class?
          klass = self
          klass = klass.superclass until klass.base_class?
        end
        super
      end

      def initialize_generated_modules # :nodoc:
        generated_association_methods
      end

      def generated_association_methods # :nodoc:
        @generated_association_methods ||= begin
          mod = const_set(:GeneratedAssociationMethods, Module.new)
          private_constant :GeneratedAssociationMethods
          include mod

          mod
        end
      end

      # Returns columns which shouldn't be exposed while calling +#inspect+.
      def filter_attributes
        if defined?(@filter_attributes)
          @filter_attributes
        else
          superclass.filter_attributes
        end
      end

      # Specifies columns which shouldn't be exposed while calling +#inspect+.
      def filter_attributes=(filter_attributes)
        @inspection_filter = nil
        @filter_attributes = filter_attributes
      end

      def inspection_filter # :nodoc:
        if defined?(@filter_attributes)
          @inspection_filter ||= begin
            mask = InspectionMask.new(ActiveSupport::ParameterFilter::FILTERED)
            ActiveSupport::ParameterFilter.new(@filter_attributes, mask: mask)
          end
        else
          superclass.inspection_filter
        end
      end

      # Returns a string like 'Post(id:integer, title:string, body:text)'
      def inspect # :nodoc:
        if self == Formed::Base
          super
        else
          attr_list = attribute_types.map { |name, type| "#{name}: #{type.type}" } * ", "
          "#{super}(#{attr_list})"
        end
      end

      # Override the default class equality method to provide support for decorated models.
      def ===(object) # :nodoc:
        object.is_a?(self)
      end
    end
  end
end

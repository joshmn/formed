# frozen_string_literal: true

module Formed
  module Attributes
    extend ActiveSupport::Concern

    def _has_attribute?(name)
      attributes.key?(name)
    end

    def attribute_present?(attr_name)
      attr_name = attr_name.to_s
      attr_name = self.class.attribute_aliases[attr_name] || attr_name
      value = _read_attribute(attr_name)
      !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
    end

    def type_for_attribute(attr)
      self.class.attribute_types[attr].type
    end

    def column_for_attribute(attr)
      model.column_for_attribute(attr)
    end

    def has_attribute?(attr_name)
      attr_name = attr_name.to_s
      attr_name = self.class.attribute_aliases[attr_name] || attr_name
      @attributes.key?(attr_name)
    end

    def attributes_with_values
      attributes.select { |_, v| v.present? }
    end

    module ClassMethods
      def _has_attribute?(name)
        attribute_types.key?(name.to_s)
      end
    end
  end
end

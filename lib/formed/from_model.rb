# frozen_string_literal: true

module Formed
  module FromModel
    class FromModelAssignment
      def self.call(instance, record)
        record.attributes.each do |k, v|
          instance.public_send("#{k}=", v) if instance.attributes.key?(k)
        end
        record._reflections.each do |attr, _record_reflection|
          next unless (form_reflection = instance._reflections[attr])

          case form_reflection.macro
          when :has_one
            instance.send("build_#{attr}").from_model(record.public_send(attr))
          when :has_many
            record.public_send(attr).each do |associated_record|
              instance.public_send(attr).build.from_model(associated_record)
            end
          end
        end

        instance.id = record.id
        instance.map_model(record)
        instance
      end
    end

    extend ActiveSupport::Concern

    def from_model(model)
      FromModelAssignment.call(self, model)
    end

    module ClassMethods
      def from_model(model)
        new.from_model(model)
      end
    end
  end
end

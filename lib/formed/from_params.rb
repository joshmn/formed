# frozen_string_literal: true

module Formed
  module FromParams
    extend ActiveSupport::Concern

    class FromParamsAssignment
      def self.call(instance, attributes_hash)
        attributes_hash.each do |k, v|
          if instance.attributes.key?(k.to_s)
            instance.public_send("#{k}=", v)
          elsif instance.respond_to?("#{k}=")
            instance.public_send("#{k}=", v)
          end
        end

        instance
      end
    end

    def from_params(params, additional_params = {})
      attributes_hash = params.merge(additional_params)

      FromParamsAssignment.call(self, attributes_hash)
    end

    module ClassMethods
      def from_params(params, additional_params = {})
        new.from_params(params, additional_params)
      end
    end
  end
end

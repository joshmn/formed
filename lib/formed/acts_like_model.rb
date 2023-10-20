# frozen_string_literal: true

module Formed
  module ActsLikeModel
    extend ActiveSupport::Concern

    module ClassMethods
      def inherit_model_validations(model, *attributes)
        attributes.each do |attr|
          model._validators[attr].each do |validator|
            if validator.options.none?
              validates attr, validator.kind => true
            else
              validates attr, validator.kind => validator.options
            end
          end
        end
      end

      def acts_like_model(model)
        self.model = model
      end
    end

    def map_model(record); end
  end
end

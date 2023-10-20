# frozen_string_literal: true

module Formed
  module Associations
    class HasOneAssociation < SingularAssociation # :nodoc:
      include ForeignAssociation

      private

      def replace(record, _save = true)
        return target unless load_target || record

        target

        self.target = record
      end

      def set_new_record(record)
        replace(record, false)
      end

      def nullify_owner_attributes(_record)
        nil
      end
    end
  end
end

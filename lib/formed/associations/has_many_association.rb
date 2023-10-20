# frozen_string_literal: true

module Formed
  module Associations
    class HasManyAssociation < CollectionAssociation # :nodoc:
      include ForeignAssociation

      def insert_record(record, validate = true, raise = false)
        set_owner_attributes(record)
        super
      end

      private

      # Returns the number of records in this collection.
      #
      # If the association has a counter cache it gets that value. Otherwise
      # it will attempt to do a count via SQL, bounded to <tt>:limit</tt> if
      # there's one. Some configuration options like :group make it impossible
      # to do an SQL count, in those cases the array count will be used.
      #
      # That does not depend on whether the collection has already been loaded
      # or not. The +size+ method is the one that takes the loaded flag into
      # account and delegates to +count_records+ if needed.
      #
      # If the collection is empty the target is set to an empty array and
      # the loaded flag is set to true as well.
      def count_records
        count = if reflection.has_cached_counter?
                  owner.read_attribute(reflection.counter_cache_column).to_i
                else
                  scope.count(:all)
                end

        # If there's nothing in the database, @target should only contain new
        # records or be an empty array. This is a documented side-effect of
        # the method that may avoid an extra SELECT.
        if count.zero?
          target.select!(&:new_record?)
          loaded!
        end

        [10, count].compact.min
      end

      def _create_record(attributes, *)
        if attributes.is_a?(Array)
          super
        else
          update_counter_if_success(super, 1)
        end
      end

      def difference(a, b)
        a - b
      end

      def intersection(a, b)
        a & b
      end
    end
  end
end

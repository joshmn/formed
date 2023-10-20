# frozen_string_literal: true

module Formed
  module Associations
    class CollectionAssociation < Association # :nodoc:
      # Implements the reader method, e.g. foo.items for Foo.has_many :items
      def reader
        ensure_klass_exists!

        reload if stale_target?

        @proxy ||= CollectionProxy.create(klass, self)
        @proxy.reset_scope
      end

      def writer(records)
        replace(records)
      end

      def reset
        super
        @target = []
        @replaced_or_added_targets = Set.new
        @association_ids = nil
      end

      def build(attributes = nil, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| build(attr, &block) }
        else
          add_to_target(build_record(attributes, &block), replace: true)
        end
      end

      # Add +records+ to this association. Since +<<+ flattens its argument list
      # and inserts each record, +push+ and +concat+ behave identically.
      def concat(*records)
        records = records.flatten
        load_target if owner.new_record?
        concat_records(records)
      end

      # Returns the size of the collection by executing a SELECT COUNT(*)
      # query if the collection hasn't been loaded, and calling
      # <tt>collection.size</tt> if it has.
      #
      # If the collection has been already loaded +size+ and +length+ are
      # equivalent. If not and you are going to need the records anyway
      # +length+ will take one less query. Otherwise +size+ is more efficient.
      #
      # This method is abstract in the sense that it relies on
      # +count_records+, which is a method descendants have to provide.
      def size
        if !find_target? || loaded?
          target.size
        elsif @association_ids
          @association_ids.size
        elsif !association_scope.group_values.empty?
          load_target.size
        else
          unsaved_records = target.select(&:new_record?)
          unsaved_records.size + count_records
        end
      end

      # Returns true if the collection is empty.
      #
      # If the collection has been loaded
      # it is equivalent to <tt>collection.size.zero?</tt>. If the
      # collection has not been loaded, it is equivalent to
      # <tt>!collection.exists?</tt>. If the collection has not already been
      # loaded and you are going to fetch the records anyway it is better to
      # check <tt>collection.length.zero?</tt>.
      def empty?
        if loaded? || @association_ids || reflection.has_cached_counter?
          size.zero?
        else
          target.empty? && !scope.exists?
        end
      end

      # Replace this collection with +other_array+. This will perform a diff
      # and delete/add only records that have changed.
      def replace(other_array)
        other_array = other_array.map do |other|
          if other.class < Formed::Base
            other
          else
            build_record(other)
          end
        end
        original_target = load_target.dup

        if owner.new_record?
          replace_records(other_array, original_target)
        else
          replace_common_records_in_memory(other_array, original_target)
          if other_array != original_target
            transaction { replace_records(other_array, original_target) }
          else
            other_array
          end
        end
      end

      def include?(record)
        if record.is_a?(reflection.klass)
          if record.new_record?
            include_in_memory?(record)
          else
            loaded? ? target.include?(record) : scope.exists?(record.id)
          end
        else
          false
        end
      end

      def load_target
        @target = merge_target_lists(find_target, target) if find_target?

        loaded!
        target
      end

      def add_to_target(record, skip_callbacks: false, replace: true, &block)
        replace_on_target(record, skip_callbacks, replace: replace, &block)
      end

      def target=(record)
        return super unless reflection.klass.has_many_inversing

        case record
        when nil
          # It's not possible to remove the record from the inverse association.
        when Array
          super
        else
          replace_on_target(record, true, replace: true, inversing: true)
        end
      end

      def scope
      end

      def null_scope?
        owner.new_record?
      end

      def find_from_target?
        loaded? ||
          owner.strict_loading? ||
          reflection.strict_loading? ||
          owner.new_record? ||
          target.any? { |record| record.new_record? || record.changed? }
      end

      private

      def merge_target_lists(persisted, memory)
        return persisted if memory.empty?

        persisted.map! do |record|
          if (mem_record = memory.delete(record))

            ((record.attribute_names & mem_record.attribute_names) - mem_record.changed_attribute_names_to_save).each do |name|
              mem_record[name] = record[name]
            end

            mem_record
          else
            record
          end
        end

        persisted + memory.reject(&:persisted?)
      end

      def _create_record(attributes, raise = false, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| _create_record(attr, raise, &block) }
        else
          build_record(attributes, &block)
        end
      end

      def replace_records(new_target, original_target)
        unless concat(difference(new_target, target))
          @target = original_target
          raise RecordNotSaved, "Failed to replace #{reflection.name} because one or more of the " \
                                  "new records could not be saved."
        end

        target
      end

      def replace_common_records_in_memory(new_target, original_target)
        common_records = intersection(new_target, original_target)
        common_records.each do |record|
          skip_callbacks = true
          replace_on_target(record, skip_callbacks, replace: true)
        end
      end

      def concat_records(records, raise = false)
        result = true

        records.each do |record|
          add_to_target(record) do
            unless owner.new_record?
              result &&= insert_record(record, true, raise) do
                @_was_loaded = loaded?
              end
            end
          end
        end

        records
      end

      def replace_on_target(record, skip_callbacks, replace:, inversing: false)
        index = @target.index(record) if replace && (!record.new_record? || @replaced_or_added_targets.include?(record))

        unless skip_callbacks
          catch(:abort) do
            callback(:before_add, record)
          end || return
        end

        set_inverse_instance(record)

        @_was_loaded = true

        yield(record) if block_given?

        index = @target.index(record) if !index && @replaced_or_added_targets.include?(record)

        @replaced_or_added_targets << record if inversing || index || record.new_record?

        if index
          target[index] = record
        elsif @_was_loaded || !loaded?
          @association_ids = nil
          target << record
        end

        callback(:after_add, record) unless skip_callbacks

        record
      ensure
        @_was_loaded = nil
      end

      def callback(method, record)
        callbacks_for(method).each do |callback|
          callback.call(method, owner, record)
        end
      end

      def callbacks_for(callback_name)
        full_callback_name = "#{callback_name}_for_#{reflection.name}"
        if owner.class.respond_to?(full_callback_name)
          owner.class.send(full_callback_name)
        else
          []
        end
      end

      def include_in_memory?(record)
        if reflection.is_a?(Formed::Reflection::ThroughReflection)
          assoc = owner.association(reflection.through_reflection.name)
          assoc.reader.any? do |source|
            target_reflection = source.send(reflection.source_reflection.name)
            target_reflection.respond_to?(:include?) ? target_reflection.include?(record) : target_reflection == record
          end || target.include?(record)
        else
          target.include?(record)
        end
      end

      # If the :inverse_of option has been
      # specified, then #find scans the entire collection.
      def find_by_scan(*args)
        expects_array = args.first.is_a?(Array)
        ids           = args.flatten.compact.map(&:to_s).uniq

        if ids.size == 1
          id = ids.first
          record = load_target.detect { |r| id == r.id.to_s }
          expects_array ? [record] : record
        else
          load_target.select { |r| ids.include?(r.id.to_s) }
        end
      end
    end
  end
end

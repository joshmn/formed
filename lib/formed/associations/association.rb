# frozen_string_literal: true

module Formed
  module Associations
    class Association # :nodoc:
      attr_reader :owner, :target, :reflection, :disable_joins

      delegate :options, to: :reflection

      def initialize(owner, reflection)
        reflection.check_validity!

        @owner = owner
        @reflection = reflection

        reset
        reset_scope
      end

      def reset
        @loaded = true
        @target = nil
        @stale_state = nil
      end

      def reset_negative_cache # :nodoc:
        reset if loaded? && target.nil?
      end

      # Reloads the \target and returns +self+ on success.
      # The QueryCache is cleared if +force+ is true.
      def reload(force = false)
        reset
        reset_scope
        load_target
        self unless target.nil?
      end

      def loaded?
        @loaded
      end

      # Asserts the \target has been loaded setting the \loaded flag to +true+.
      def loaded!
        @loaded = true
        @stale_state = stale_state
      end

      def stale_target?
        loaded? && @stale_state != stale_state
      end

      def target=(target)
        @target = target
        loaded!
      end

      def scope
        target
      end

      def reset_scope
        @association_scope = nil
      end

      # Set the inverse association, if possible
      def set_inverse_instance(record)
        if (inverse = inverse_association_for(record))
          inverse.inversed_from(owner)
        end
        record
      end

      def klass
        reflection.klass
      end

      def extensions
        extensions = reflection.extensions

        extensions |= reflection.scope_for(klass.unscoped, owner).extensions if reflection.scope

        extensions
      end

      def load_target
        @target = find_target if (@stale_state && stale_target?) || find_target?

        loaded! unless loaded?
        target
      end

      # We can't dump @reflection and @through_reflection since it contains the scope proc
      def marshal_dump
        ivars = (instance_variables - %i[@reflection @through_reflection]).map do |name|
          [name, instance_variable_get(name)]
        end
        [@reflection.name, ivars]
      end

      def marshal_load(data)
        reflection_name, ivars = data
        ivars.each { |name, val| instance_variable_set(name, val) }
        @reflection = @owner.class._reflect_on_association(reflection_name)
      end

      def initialize_attributes(record, except_from_scope_attributes = nil) # :nodoc:
        except_from_scope_attributes ||= {}
        skip_assign = [reflection.foreign_key, reflection.type].compact
        assigned_keys = record.changed
        assigned_keys += except_from_scope_attributes.keys.map(&:to_s)
        attributes = {}.except!(*(assigned_keys - skip_assign))
        record.send(:_assign_attributes, attributes) if attributes.any?
        set_inverse_instance(record)
      end

      private

      # Reader and writer methods call this so that consistent errors are presented
      # when the association target class does not exist.
      def ensure_klass_exists!
        klass
      end

      def find_target

      end

      def violates_strict_loading?
        return reflection.strict_loading? if reflection.options.key?(:strict_loading)

        false # owner.strict_loading? && !owner.strict_loading_n_plus_one_only?
      end

      def association_scope
        klass
      end

      def target_scope
        AssociationRelation.create(klass, self).merge!({})
      end

      def find_target?
        !loaded? && (!owner.new_record?) && klass
      end

      def inverse_association_for(record)
        return unless invertible_for?(record)

        record.association(inverse_reflection_for(record).name)
      end

      # Returns true if inverse association on the given record needs to be set.
      # This method is redefined by subclasses.
      def invertible_for?(record)
        foreign_key_for?(record) && inverse_reflection_for(record)
      end

      # Returns true if record contains the foreign_key
      def foreign_key_for?(record)
        record._has_attribute?(reflection.foreign_key)
      end

      # This should be implemented to return the values of the relevant key(s) on the owner,
      # so that when stale_state is different from the value stored on the last find_target,
      # the target is stale.
      #
      # This is only relevant to certain associations, which is why it returns +nil+ by default.
      def stale_state; end

      def build_record(attributes)
        reflection.build_association(attributes) do |record|
          initialize_attributes(record, attributes)
          yield(record) if block_given?
        end
      end

      def inversable?(record)
        record &&
          ((!record.persisted? || !owner.persisted?) || matches_foreign_key?(record))
      end

      def matches_foreign_key?(record)
        if foreign_key_for?(record)
          record.read_attribute(reflection.foreign_key) == owner.id ||
            (foreign_key_for?(owner) && owner.read_attribute(reflection.foreign_key) == record.id)
        else
          owner.read_attribute(reflection.foreign_key) == record.id
        end
      end
    end
  end
end

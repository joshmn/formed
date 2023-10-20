# frozen_string_literal: true

module Formed
  class Relation
    include Enumerable

    attr_reader :klass, :loaded
    attr_accessor :skip_preloading_value
    alias model klass
    alias loaded? loaded

    include Delegation

    def initialize(klass, values: {})
      @klass  = klass
      @values = values
      @loaded = true
      @delegate_to_klass = false
      @future_result = nil
      @records = nil
    end

    def initialize_copy(_other)
      @values = @values.dup
      reset
    end

    # Initializes new record from relation while maintaining the current
    # scope.
    #
    # Expects arguments in the same format as {ActiveRecord::Base.new}[rdoc-ref:Core.new].
    #
    #   users = User.where(name: 'DHH')
    #   user = users.new # => #<User id: nil, name: "DHH", created_at: nil, updated_at: nil>
    #
    # You can also pass a block to new with the new record as argument:
    #
    #   user = users.new { |user| user.name = 'Oscar' }
    #   user.name # => Oscar
    def new(attributes = nil, &block)
      if attributes.is_a?(Array)
        attributes.collect { |attr| new(attr, &block) }
      else
        block = current_scope_restoring_block(&block)
        scoping { _new(attributes, &block) }
      end
    end
    alias build new

    # Converts relation objects to Array.
    def to_ary
      records.dup
    end
    alias to_a to_ary

    def records # :nodoc:
      @records
    end

    # Serializes the relation objects Array.
    def encode_with(coder)
      coder.represent_seq(nil, records)
    end

    # Returns size of the records.
    def size
      if loaded?
        records.length
      else
        count(:all)
      end
    end

    # Returns true if there are no records.
    def empty?
      if loaded?
        records.empty?
      else
        !exists?
      end
    end

    # Returns true if there are no records.
    def none?
      return super if block_given?

      empty?
    end

    # Returns true if there are any records.
    def any?
      return super if block_given?

      !empty?
    end

    # Returns true if there is exactly one record.
    def one?
      return super if block_given?
      return records.one? if loaded?

      limited_count == 1
    end

    # Returns true if there is more than one record.
    def many?
      return super if block_given?
      return records.many? if loaded?

      limited_count > 1
    end
  end
end

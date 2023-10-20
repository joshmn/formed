# frozen_string_literal: true

require "formed/relation/delegation"
require "formed/associations"
require "formed/core"
require "formed/inheritance"
require "formed/reflection"
require "formed/relation"
require "formed/attributes"
require "formed/nested_attributes"
require "formed/association_relation"
require "formed/associations/association"
require "formed/associations/singular_association"
require "formed/associations/collection_association"
require "formed/associations/foreign_association"
require "formed/associations/collection_proxy"
require "formed/associations/builder"
require "formed/associations/builder/association"
require "formed/associations/builder/singular_association"
require "formed/associations/builder/collection_association"
require "formed/associations/builder/has_one"
require "formed/associations/builder/has_many"
require "formed/associations/has_many_association"
require "formed/associations/has_one_association"

require "formed/acts_like_model"
require "formed/from_model"
require "formed/from_params"

module Formed
  RESTRICTED_CLASS_METHODS = %w(private public protected allocate new name parent superclass)

  class FormedError < StandardError
  end

  class AssociationTypeMismatch < FormedError
  end

  class Base
    extend  Relation::Delegation::DelegateCache

    include Formed::Associations
    include ActiveModel::Model
    include ActiveModel::Validations
    include ActiveModel::Attributes
    include ActiveModel::AttributeAssignment
    include ActiveModel::AttributeMethods
    include ActiveModel::Callbacks
    include ActiveModel::Dirty
    include Formed::Attributes

    include Formed::Core
    include Formed::Inheritance
    include Formed::Reflection
    include Formed::NestedAttributes

    include Formed::ActsLikeModel
    include Formed::FromParams
    include FromModel

    def init_internals
      @marked_for_destruction   = false
      @association_cache = {}
      klass = self.class

      @strict_loading      = false
      @strict_loading_mode = :all

      klass.define_attribute_methods
    end

    def initialize_internals_callback; end

    def initialize(attributes = nil)
      @new_record = true
      @attributes = self.class._default_attributes.deep_dup

      init_internals
      initialize_internals_callback

      assign_attributes(attributes) if attributes

      yield self if block_given?
      _run_initialize_callbacks
    end

    class_attribute :inheritance_column, default: :type

    define_model_callbacks :initialize, only: [:after]
    define_model_callbacks :validation, only: %i[before after]

    attribute :id, :integer
    attribute :_destroy, :boolean

    class_attribute :model
    class_attribute :primary_key, default: "id"
    class_attribute :model_name
    class_attribute :default_ignored_attributes, default: %w[id created_at updated_at]
    class_attribute :ignored_attributes, default: []

    def with_context(contexts = {})
      @context = OpenStruct.new(contexts)
      _reflections.each do |_, reflection|
        if (instance = public_send(reflection.name))
          instance.with_context(@context)
        end
      end

      self
    end

    attr_reader :context

    def inspect
      # We check defined?(@attributes) not to issue warnings if the object is
      # allocated but not initialized.
      inspection = if defined?(@attributes) && @attributes
                     self.class.attribute_names.filter_map do |name|
                       "#{name}: #{_read_attribute(name).inspect}" if self.class.attribute_types.key?(name)
                     end.join(", ")
                   else
                     "not initialized"
                   end

      "#<#{self.class} #{inspection}>"
    end

    def persisted?
      id.present? && id.to_i.positive?
    end

    def self.from_json(json)
      params = JSON.parse(json)
      from_params(params)
    end

    def valid?(options = {})
      run_callbacks(:validation) do
        options     = {} if options.blank?
        context     = options[:context]
        validations = [super(context)]

        validations.all?
      end
    end

    def invalid?(options = {})
      !valid?(options)
    end

    def to_key
      [id]
    end

    def self.model_name
      if model.is_a?(Symbol)
        ActiveModel::Name.new(self, nil, model.to_s)
      elsif model.present?
        ActiveModel::Name.new(self, nil, model.model_name.name.split("::").last)
      else
        name = self.name.demodulize.delete_suffix("Form")
        name = self.name if name.blank?
        ActiveModel::Name.new(self, nil, name)
      end
    end

    def model_name
      self.class.model_name
    end

    def new_record?
      !persisted?
    end

    def marked_for_destruction?
      attributes["_destroy"]
    end

    def destroy?
      _destroy
    end
  end
end

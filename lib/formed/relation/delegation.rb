# frozen_string_literal: true

module Formed
  class Relation
    module Delegation # :nodoc:
      class << self
        def delegated_classes
          [
            Formed::Relation,
            Formed::Associations::CollectionProxy,
            Formed::AssociationRelation
          ]
        end

        def uncacheable_methods
          @uncacheable_methods ||= (
            delegated_classes.flat_map(&:public_instance_methods) - Formed::Relation.public_instance_methods
          ).to_set.freeze
        end
      end

      module DelegateCache # :nodoc:
        def relation_delegate_class(klass)
          @relation_delegate_cache[klass]
        end

        def initialize_relation_delegate_cache
          @relation_delegate_cache = cache = {}
          Delegation.delegated_classes.each do |klass|
            delegate = Class.new(klass) do
              include ClassSpecificRelation
            end
            include_relation_methods(delegate)
            mangled_name = klass.name.gsub("::", "_")
            const_set mangled_name, delegate
            private_constant mangled_name

            cache[klass] = delegate
          end
        end

        def inherited(child_class)
          child_class.initialize_relation_delegate_cache
          super
        end

        def generate_relation_method(method)
          generated_relation_methods.generate_method(method)
        end

        protected

        def include_relation_methods(delegate)
          superclass.include_relation_methods(delegate) unless base_class?
          delegate.include generated_relation_methods
        end

        private

        def generated_relation_methods
          @generated_relation_methods ||= GeneratedRelationMethods.new.tap do |mod|
            const_set(:GeneratedRelationMethods, mod)
            private_constant :GeneratedRelationMethods
          end
        end
      end

      class GeneratedRelationMethods < Module # :nodoc:
        include Mutex_m

        def generate_method(method)
          synchronize do
            return if method_defined?(method)

            if /\A[a-zA-Z_]\w*[!?]?\z/.match?(method) && !DELEGATION_RESERVED_METHOD_NAMES.include?(method.to_s)
              module_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{method}(...)
                scoping { klass.#{method}(...) }
              end
              RUBY
            else
              define_method(method) do |*args, &block|
                scoping { klass.public_send(method, *args, &block) }
              end
              ruby2_keywords(method)
            end
          end
        end
      end
      private_constant :GeneratedRelationMethods

      extend ActiveSupport::Concern

      # This module creates compiled delegation methods dynamically at runtime, which makes
      # subsequent calls to that method faster by avoiding method_missing. The delegations
      # may vary depending on the klass of a relation, so we create a subclass of Relation
      # for each different klass, and the delegations are compiled into that subclass only.

      delegate :to_xml, :encode_with, :length, :each, :join, :intersects?,
               :[], :&, :|, :+, :-, :sample, :reverse, :rotate, :compact, :in_groups, :in_groups_of,
               :to_sentence, :to_fs, :to_formatted_s, :as_json,
               :shuffle, :split, :slice, :index, :rindex, to: :records

      delegate :primary_key, :connection, to: :klass

      module ClassSpecificRelation # :nodoc:
        extend ActiveSupport::Concern

        module ClassMethods # :nodoc:
          def name
            superclass.name
          end
        end

        private

        def method_missing(method, *args, &block)
          if @klass.respond_to?(method)
            @klass.generate_relation_method(method) unless Delegation.uncacheable_methods.include?(method)
            scoping { @klass.public_send(method, *args, &block) }
          else
            super
          end
        end
        ruby2_keywords(:method_missing)
      end

      module ClassMethods # :nodoc:
        def create(klass, *args, **kwargs)
          relation_class_for(klass).new(klass, *args, **kwargs)
        end

        private

        def relation_class_for(klass)
          klass.relation_delegate_class(self)
        end
      end

      private

      def respond_to_missing?(method, _)
        super || @klass.respond_to?(method)
      end
    end
  end
end

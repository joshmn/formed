# frozen_string_literal: true

module Formed
  class AssociationRelation < Relation # :nodoc:
    def initialize(klass, association, **)
      super(klass)
      @association = association
    end

    def proxy_association
      @association
    end

    def ==(other)
      other == records
    end

    def merge!(other, *rest) # :nodoc:
      # no-op #
    end
  end
end

# frozen_string_literal: true

require_relative "user_form"

class ChildForm < UserForm
  acts_like_model :User

  attribute :school, :string

  validates :school, presence: true
end

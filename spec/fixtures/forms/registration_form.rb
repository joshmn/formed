# frozen_string_literal: true

class RegistrationForm < Formed::Base
  attribute :email

  validates :email, presence: true
end

# frozen_string_literal: true

class PhoneForm < Formed::Base
  attribute :number, :string
  attribute :country_code, :string
end

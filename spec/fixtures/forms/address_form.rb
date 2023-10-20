# frozen_string_literal: true

class AddressForm < Formed::Base
  attribute :street,    :string
  attribute :town,      :string
  attribute :city,      :string
  attribute :post_code, :string
end

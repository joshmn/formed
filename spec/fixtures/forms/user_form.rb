# frozen_string_literal: true

require_relative "address_form"
require_relative "contact_form"

class UserForm < Formed::Base
  acts_like_model :user

  attribute :user,        :string
  attribute :first_name,  :string
  attribute :age,         :integer
  attribute :colours,     array: true
  has_one :address, class_name: "AddressForm"
  has_many :contacts, class_name: "ContactForm"
  attribute :order_count, :integer
  attribute :other_id,    :integer
  attribute :last_login_date, :string

  validates :first_name, presence: true

  accepts_nested_attributes_for :address
  accepts_nested_attributes_for :contacts

  def map_model(model)
    self.last_login_date = model.last_logged_in.strftime("%d/%m/%Y")
  end
end

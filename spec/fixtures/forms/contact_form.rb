# frozen_string_literal: true

require_relative "phone_form"

class ContactForm < Formed::Base
  attribute :name,   :string
  attribute :number, :string

  has_many :phones, class_name: "PhoneForm"
  accepts_nested_attributes_for :phones
  validates :name, presence: true
end

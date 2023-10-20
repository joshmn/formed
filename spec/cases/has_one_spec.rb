# frozen_string_literal: true

require "spec_helper"

describe "HasOne" do
  class TicketForm < Formed::Base
    has_one :customer, class_name: "CustomerForm"
    accepts_nested_attributes_for :customer
  end

  class CustomerForm < Formed::Base
    attribute :name
  end

  class HumanForm < Formed::Base
  end

  it "is reflected" do
    expect(TicketForm._reflections).to include("customer")
  end

  it "has the association" do
    expect(TicketForm._reflections["customer"].macro).to eq(:has_one)
  end

  context "setter" do
    it "sets the record" do
      ticket_form = TicketForm.new
      customer = CustomerForm.new(name: "bob")
      ticket_form.customer = customer
      expect(ticket_form.customer).to eq(customer)
    end
  end

  context "nested attributes" do
    it "works" do
      instance = TicketForm.from_params({ customer_attributes: { name: "bob" } })
      expect(instance.customer.name).to eq("bob")
    end
  end

  context "derived class name" do
    it "appends form" do
      HumanForm.has_many :tickets
      expect(HumanForm.new.association(:tickets).klass).to eq(TicketForm)
    end
  end
end

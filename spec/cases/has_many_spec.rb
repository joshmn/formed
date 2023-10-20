# frozen_string_literal: true

require "spec_helper"

describe "HasOne" do
  class OrderForm < Formed::Base
    has_many :barcodes, class_name: "BarcodeForm"
  end

  class BarcodeForm < Formed::Base
    attribute :code

    validates :code, presence: true
  end

  context "validations" do
    it "validates" do
      order = OrderForm.new
      order.barcodes.new
      order.validate
      expect(order.valid?).to be_falsey
    end
  end

  context "methods" do
    it "size" do
      order = OrderForm.new
      order.barcodes.new
      expect(order.barcodes.size).to eq(1)
    end

    it "count" do
      order = OrderForm.new
      order.barcodes.new
      expect(order.barcodes.count).to eq(1)
    end
  end
end

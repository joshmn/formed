# frozen_string_literal: true

require "spec_helper"

require "action_controller/metal/strong_parameters"

describe Formed::FromParams do
  class Form < Formed::Base
    attribute :money
  end

  let(:params) { ActionController::Parameters.new({ money: "here", not_existing: "there" }) }

  context "class method" do
    let(:form) { Form.from_params(params) }

    it "assigns the attributes that exist" do
      expect(form.money).to eq("here")
    end
  end

  context "instance method" do
    let(:form) do
      instance = Form.new
      instance.from_params(params)
    end

    it "assigns the attributes that exist" do
      expect(form.money).to eq("here")
    end
  end

  after(:all) do
    Object.send(:remove_const, :Form)
  end
end

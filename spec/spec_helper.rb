# frozen_string_literal: true
if ENV['CI'] == 'true'
  require 'simplecov'
  SimpleCov.start
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require "pry"
require "rails/all"

require "formed"

Dir["spec/fixtures/**/*.rb"].each { |f| require File.expand_path(f) }
require "action_controller/metal/strong_parameters"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = Logger.new($stdout)

ActiveRecord::Schema.define do
  create_table "addresses", force: :cascade do |t|
    t.string "street", default: "", null: false
    t.string "town", default: "", null: false
    t.string "city", default: "", null: false
    t.string "post_code", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "contacts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", default: "", null: false
    t.string "number", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_contacts_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "first_name", default: "", null: false
    t.integer "age", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: true, null: false
    t.integer "address_id"
    t.datetime "last_logged_in"
    t.string "user"
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.around(:each) do |test|
    ActiveRecord::Base.transaction do
      test.run
      raise ActiveRecord::Rollback
    end
  end

  config.formatter = :documentation
  config.backtrace_exclusion_patterns << /gems/
  config.order = "random"

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

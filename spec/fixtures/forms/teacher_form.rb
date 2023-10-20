# frozen_string_literal: true

class TeacherForm < Formed::Base
  attribute :name, :string

  validates :name, presence: true
end

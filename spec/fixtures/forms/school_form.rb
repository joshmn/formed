# frozen_string_literal: true

require_relative "teacher_form"

class SchoolForm < Formed::Base
  has_one :head, class_name: "TeacherForm", required: true
end

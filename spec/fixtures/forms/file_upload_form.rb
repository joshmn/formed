# frozen_string_literal: true

class FileUploadForm < Formed::Base
  acts_like_model :user

  attribute :file # , ActionDispatch::Http::UploadedFile
end

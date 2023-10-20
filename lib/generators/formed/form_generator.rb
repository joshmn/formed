require 'rails/generators'

module Formed
  module Generators # :nodoc:
    class FormGenerator < Rails::Generators::NamedBase # :nodoc:
      source_root File.join(__dir__, "templates")

      argument :attributes, type: :array, default: [], banner: "field[:type] field[:type]"
      class_option :model, type: :string, desc: "The model name for the generated form"
      class_option :parent, type: :string, default: "ApplicationForm", desc: "The parent class for the generated form"

      def create_model_file
        generate_abstract_class if !custom_parent?

        template "form.rb", File.join("app/forms", class_path, "#{file_name}.rb")
      end

      def create_module_file
        return if regular_class_path.empty?

        template "module.rb", File.join("app/forms", "#{class_path.join('/')}.rb") if behavior == :invoke
      end

      def create_rspec_file
        return unless Rails.application.config.generators.test_framework == :rspec

        template 'form_spec.rb',  File.join("spec/forms", class_path, "#{file_name}_spec.rb")
      end

      def file_name
        name = super
        unless name.end_with?("_form")
          name += "_form"
        end
        name
      end

      def class_name
        name = super
        unless name.end_with?("Form")
          name += "Form"
        end
        name
      end

      private

      def parent_class_name
        parent
      end

      def generate_abstract_class
        path = File.join("app/forms", "application_form.rb")
        return if File.exist?(path)

        template "abstract_base_class.rb", path
      end

      def abstract_class_name
        "ApplicationForm"
      end

      def parent
        options[:parent]
      end

      def custom_parent?
        parent != self.class.class_options[:parent].default
      end
    end
  end
end

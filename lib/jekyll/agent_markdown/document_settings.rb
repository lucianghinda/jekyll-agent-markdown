# frozen_string_literal: true

require "jekyll"
require_relative "configuration"

module Jekyll
  module AgentMarkdown
    class DocumentSettings
      ALLOWED_SETTINGS = %w[export index section optional include_document_header].freeze

      attr_reader :section

      def initialize(document, settings, source_kind:, collection_name: nil)
        @document = document
        @settings = settings
        @source_kind = SourceSettings.kind(source_kind, document_path)
        @collection_name = SourceSettings.collection_name(collection_name, @source_kind, document_path)

        apply(normalized_document_settings)
      end

      def export? = @export

      def index? = @index

      def optional? = @optional

      def include_document_header? = @include_document_header

      private

      attr_reader :document, :settings, :source_kind, :collection_name

      def normalized_document_settings
        value = document.data.fetch("agent_markdown", true)
        if value.is_a?(Hash)
          return value.to_h { |key, setting| [key.to_s, setting] }.tap do |normalized|
            validate_keys!(normalized)
            validate_values!(normalized)
          end
        end

        Configuration.enabled_value?(value, name: setting_name)
        return { "export" => false, "index" => false } if Configuration.disabled?(value)

        {}
      end

      def validate_keys!(document_settings)
        unknown = document_settings.keys - ALLOWED_SETTINGS
        return if unknown.empty?

        suffix = "s" if unknown.length > 1
        configuration_error("unknown agent_markdown setting#{suffix}: #{unknown.sort.join(", ")}")
      end

      def validate_values!(document_settings)
        %w[export index optional include_document_header].each do |key|
          next unless document_settings.key?(key)

          Configuration.enabled_value?(document_settings.fetch(key), name: "agent_markdown.#{key} in #{document_path}")
        end

        return unless document_settings.key?("section")

        section = document_settings.fetch("section")
        return if section.is_a?(String) && !section.strip.empty?

        configuration_error("agent_markdown.section must be a non-empty String; got #{section.inspect}")
      end

      def apply(document_settings)
        @export, @index = export_status(document_settings)
        @optional, @section = placement(document_settings)
        @include_document_header = enabled_value(
          document_settings,
          "include_document_header",
          Configuration.enabled?(settings, "include_document_header")
        )
      end

      def export_status(document_settings)
        source_enabled = source_enabled?
        export = enabled_value(document_settings, "export", source_enabled)
        index = enabled_value(document_settings, "index", source_enabled)
        validate_export_and_index!(document_settings, index)
        export &&= source_enabled
        [export, export && index]
      end

      def validate_export_and_index!(document_settings, index)
        return unless explicitly_disabled?(document_settings, "export") && document_settings.key?("index") && index

        configuration_error("agent_markdown.export cannot be false when agent_markdown.index is true")
      end

      def explicitly_disabled?(document_settings, key)
        document_settings.key?(key) && Configuration.disabled?(document_settings.fetch(key))
      end

      def placement(document_settings)
        optional = enabled_value(document_settings, "optional", false)
        section = SourceSettings.normalized_section(document_settings["section"])
        if optional && section
          configuration_error("agent_markdown.optional cannot be combined with agent_markdown.section")
        end

        [optional, optional ? "Optional" : section]
      end

      def enabled_value(document_settings, key, default)
        return default unless document_settings.key?(key)

        !Configuration.disabled?(document_settings.fetch(key))
      end

      def source_enabled?
        case source_kind
        when :post
          Configuration.enabled?(settings, "posts")
        when :page
          Configuration.enabled?(settings, "pages")
        when :collection
          Configuration.collection_names(settings).include?(collection_name)
        else
          false
        end
      end

      def setting_name = "agent_markdown in #{document_path}"

      def document_path
        return document.relative_path if document.respond_to?(:relative_path)
        return document.path if document.respond_to?(:path)

        "unknown document"
      end

      def configuration_error(message)
        raise Jekyll::Errors::FatalException, "#{document_path}: #{message}"
      end
    end

    module SourceSettings
      SOURCE_KINDS = %i[post page collection].freeze

      module_function

      def kind(value, document_path)
        source_kind = value.to_sym if value.respond_to?(:to_sym)
        return source_kind if SOURCE_KINDS.include?(source_kind)

        error(document_path, "unsupported source kind: #{value.inspect}")
      end

      def collection_name(value, source_kind, document_path)
        return nil unless source_kind == :collection
        return value.strip if value.is_a?(String) && !value.strip.empty?

        error(document_path, "collection_name must be a non-empty String; got #{value.inspect}")
      end

      def normalized_section(value) = value&.gsub(/\s+/, " ")&.strip

      def error(document_path, message)
        raise Jekyll::Errors::FatalException, "#{document_path}: #{message}"
      end
    end
  end
end

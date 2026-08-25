# frozen_string_literal: true

require_relative "configuration"
require_relative "llms_text"

module Jekyll
  module AgentMarkdown
    class LlmsDocumentIndex
      Section = Data.define(:name, :documents)
      OPTIONAL_KEY = "optional"

      def initialize(settings, documents)
        @settings = settings
        @documents = documents.select(&:index)
      end

      def default_compatibility?
        Configuration.enabled?(settings, "posts") &&
          !Configuration.enabled?(settings, "pages") &&
          Configuration.collection_names(settings).empty? &&
          !Configuration.enabled?(settings, "include_descriptions") &&
          documents.none? { |document| document.optional || document.section }
      end

      def sections
        @sections ||= build_sections
      end

      private

      attr_reader :settings, :documents

      def build_sections
        groups, names = grouped_documents
        section_registry(groups, names).filter_map do |key, name|
          Section.new(name, groups.fetch(key)) if groups.key?(key)
        end
      end

      def grouped_documents
        documents.each_with_object([Hash.new { |hash, key| hash[key] = [] }, {}]) do |document, entries|
          groups, names = entries
          key = resolved_section_key(document)
          groups[key] << document
          names[key] ||= section_name(document, key)
        end
      end

      def section_registry(groups, names)
        registry = default_registry.merge(custom_registry(groups, names))
        if groups.key?(OPTIONAL_KEY)
          registry.delete(OPTIONAL_KEY)
          registry[OPTIONAL_KEY] = "Optional"
        end
        registry
      end

      def default_registry
        @default_registry ||= default_section_names.each_with_object({}) do |name, registry|
          registry[section_key(name)] ||= name
        end
      end

      def custom_registry(groups, names)
        groups.each_with_object({}) do |(key, _documents), registry|
          registry[key] = names.fetch(key) if custom_section?(key)
        end
      end

      def custom_section?(key) = key != OPTIONAL_KEY && !default_registry.key?(key)

      def default_section_names
        @default_section_names ||= %w[Articles Pages] + collection_section_names
      end

      def collection_section_names
        Configuration.collection_names(settings).map { |name| humanize(name) }
      end

      def resolved_section_key(document)
        return OPTIONAL_KEY if document.optional || section_key(document.section) == OPTIONAL_KEY
        return section_key(document.section) if document.section

        implicit_section_key(document)
      end

      def section_name(document, key)
        return "Optional" if key == OPTIONAL_KEY
        return document.section if document.section

        default_registry.fetch(key)
      end

      def implicit_section_key(document)
        case document.source_kind
        when :post
          section_key("Articles")
        when :page
          section_key("Pages")
        when :collection
          section_key(humanize(collection_label(document)))
        end
      end

      def section_key(name)
        LlmsText.one_line(name).downcase.split(/[-_\s]+/).reject(&:empty?).join(" ")
      end

      def collection_label(document)
        return unless document.source_kind == :collection

        collection = document.source_document.collection
        collection.label if collection.respond_to?(:label)
      end

      def humanize(name)
        name.split(/[-_\s]+/).filter_map do |word|
          next if word.empty?

          "#{word[0].upcase}#{word[1..].to_s.downcase}"
        end.join(" ")
      end
    end
  end
end

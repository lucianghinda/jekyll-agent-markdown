# frozen_string_literal: true

require "jekyll"
require_relative "configuration"
require_relative "date_metadata"
require_relative "llms_document_index"
require_relative "llms_document_ordering"
require_relative "llms_text"

module Jekyll
  module AgentMarkdown
    class LlmsFullRenderer
      include Jekyll::Filters::URLFilters

      def initialize(site, settings, documents)
        @site = site
        @settings = settings
        @index = LlmsDocumentIndex.new(settings, documents)
        @context = Liquid::Context.new({}, {}, { site: site })
      end

      def to_s
        sections = index.sections.map { |section| render_section(section) }
        "#{([site_heading] + sections).join("\n\n")}\n"
      end

      private

      attr_reader :site, :settings, :index

      def site_heading
        "# #{LlmsText.one_line(site.config.fetch("title", ""))}".rstrip
      end

      def render_section(section)
        (["## #{LlmsText.literal(section.name)}"] + sorted(section.documents).map do |document|
          render_document(document)
        end)
          .join("\n\n")
      end

      def render_document(document)
        ["### [#{title(document)}](#{escaped_link_url(absolute_markdown_url(document))})",
         "Source: #{absolute_html_url(document)}", document.body].join("\n\n")
      end

      def sorted(documents)
        ordering = LlmsDocumentOrdering.new(settings)
        dates = proc { |document| published_date(document) }
        return ordering.legacy_ordered(documents, &dates) if index.default_compatibility?

        ordering.ordered(documents, &dates)
      end

      def absolute_markdown_url(document)
        "#{site.config.fetch("url").sub(%r{/+\z}, "")}#{relative_url(document.markdown_url)}"
      end

      def absolute_html_url(document)
        return document.html_url if document.html_url.start_with?("http://", "https://")

        "#{site.config.fetch("url").sub(%r{/+\z}, "")}#{relative_url(document.source_document.url)}"
      end

      def title(document) = LlmsText.link_title(document.source_document)

      def published_date(document) = DateMetadata.new(document.source_document.data).published_date

      def escaped_link_url(url) = LlmsText.escaped_link_url(url)
    end
  end
end

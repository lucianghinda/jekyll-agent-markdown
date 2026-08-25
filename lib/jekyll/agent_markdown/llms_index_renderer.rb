# frozen_string_literal: true

require "cgi"
require "jekyll"
require_relative "configuration"
require_relative "date_metadata"
require_relative "llms_document_index"
require_relative "llms_document_ordering"
require_relative "llms_headings"
require_relative "llms_text"

module Jekyll
  module AgentMarkdown
    class LlmsIndexRenderer
      include Jekyll::Filters::URLFilters
      include Liquid::StandardFilters

      def initialize(site, settings, documents)
        @site = site
        @settings = settings
        @index = LlmsDocumentIndex.new(settings, documents)
        @context = Liquid::Context.new({}, {}, { site: site })
      end

      def to_s
        return legacy_index if index.default_compatibility?

        sections = [LlmsHeadings.new(site, settings).to_s(include_articles: false)] +
                   index.sections.map { |section| render_section(section) }
        "#{sections.reject(&:empty?).join("\n\n")}\n"
      end

      private

      attr_reader :site, :settings, :index

      def legacy_index
        headings = LlmsHeadings.new(site, settings).to_s
        links = sorted(index.sections.first&.documents || []).map { |document| entry(document) }.join("\n")
        "#{[headings, links].reject(&:empty?).join("\n\n")}\n"
      end

      def render_section(section)
        entries = sorted(section.documents).map { |document| entry(document) }
        (["## #{LlmsText.literal(section.name)}"] + entries).join("\n")
      end

      def sorted(documents)
        ordering = LlmsDocumentOrdering.new(settings)
        dates = proc { |document| published_date(document) }
        return ordering.legacy_ordered(documents, &dates) if index.default_compatibility?

        ordering.ordered(documents, &dates)
      end

      def entry(document)
        link = "- [#{title(document)}](#{escaped_link_url(absolute_markdown_url(document))})"
        description = description_for(document)
        link += ": #{description}" unless description.empty?
        return link unless Configuration.enabled?(settings, "include_dates")

        [link, DateMetadata.new(document.source_document.data).to_s].reject(&:empty?).join(" | ")
      end

      def absolute_markdown_url(document)
        "#{site.config.fetch("url").sub(%r{/+\z}, "")}#{relative_url(document.markdown_url)}"
      end

      def title(document) = LlmsText.link_title(document.source_document)

      def published_date(document) = DateMetadata.new(document.source_document.data).published_date

      def description_for(document)
        return "" unless Configuration.enabled?(settings, "include_descriptions")

        description = description_value(document)
        return "" if description.empty?

        LlmsText.literal(inline_text(CGI.unescapeHTML(strip_html(rendered_description(description)))))
      end

      def description_value(document)
        source = document.source_document
        value = source.data["description"] || source.data["excerpt"]
        value = source.excerpt if value.nil? && source.respond_to?(:excerpt)
        value.to_s.strip
      end

      def rendered_description(description)
        markdown_converter.convert(CGI.unescapeHTML(description))
      end

      def inline_text(value) = value.gsub(/\s+/, " ").strip

      def markdown_converter
        @markdown_converter ||= site.find_converter_instance(Jekyll::Converters::Markdown)
      end

      def escaped_link_url(url) = LlmsText.escaped_link_url(url)
    end
  end
end

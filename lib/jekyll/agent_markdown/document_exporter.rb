# frozen_string_literal: true

require "jekyll"
require_relative "configuration"
require_relative "document_header"
require_relative "document_settings"
require_relative "exported_document"
require_relative "markdown_sibling_path"
require_relative "raw_markdown_file"

module Jekyll
  module AgentMarkdown
    class DocumentExporter
      include Jekyll::Filters::URLFilters

      # The published bytes and the same document without the generated header.
      # llms-full.txt renders its own heading and Source line, so inlining the
      # published bytes there would repeat both and nest a second level-one
      # heading under the section.
      Contents = Data.define(:content, :body)

      def initialize(site, settings, destination_claims, content_for_post:)
        @site = site
        @settings = settings
        @destination_claims = destination_claims
        @content_for_post = content_for_post
        @context = Liquid::Context.new({}, {}, { site: site })
        @header = DocumentHeader.new(site, method(:relative_url))
      end

      def export(document, source_kind:, collection_name: nil)
        # Opted-out and collided documents must not keep a stale or authored
        # value: the alternate-link tag reads it as proof of publication.
        document.data.delete("agent_markdown_url")
        document_settings = DocumentSettings.new(
          document, settings, source_kind: source_kind, collection_name: collection_name
        )
        return unless document_settings.export?

        claim_export(document, source_kind, document_settings)
      end

      private

      attr_reader :site, :settings, :destination_claims, :content_for_post, :header

      def claim_export(document, source_kind, document_settings)
        file, contents = markdown_file(document, source_kind, document_settings)
        return collision_warning(document, file.url) unless destination_claims.claim?(file.destination(site.dest))

        publish(document, source_kind, document_settings, file, contents)
      end

      def markdown_file(document, source_kind, document_settings)
        contents = document_contents(document, source_kind, document_settings)
        file = RawMarkdownFile.new(site, MarkdownSiblingPath.for(document.url), contents.content)
        [file, contents]
      end

      def publish(document, source_kind, document_settings, file, contents)
        document.data["agent_markdown_url"] = file.url
        site.static_files << file
        exported_document(document, source_kind, document_settings, file, contents)
      end

      def exported_document(document, source_kind, document_settings, file, contents)
        ExportedDocument.new(
          source_document: document,
          source_kind: source_kind,
          markdown_url: file.url,
          markdown_content: contents.content,
          body: contents.body,
          html_url: html_url(document, document_settings),
          **placement(document_settings)
        )
      end

      def placement(document_settings)
        {
          section: document_settings.section,
          index: document_settings.index?,
          optional: document_settings.optional?
        }
      end

      def document_contents(document, source_kind, document_settings)
        body = source_kind == :post ? content_for_post.call(document) : document.content.to_s
        return Contents.new(content: body, body: body) unless document_settings.include_document_header?

        Contents.new(content: header.prepend_to(document, body), body: body)
      end

      def html_url(document, document_settings)
        return unvalidated_html_url(document) unless document_settings.include_document_header?

        header.html_url(document)
      end

      def unvalidated_html_url(document)
        path = relative_url(document.url)
        return path unless Configuration.absolute_http_url?(site.config["url"])

        "#{site.config["url"].sub(%r{/+\z}, "")}#{path}"
      end

      def collision_warning(document, url)
        Jekyll.logger.warn "AgentMarkdown:",
                           "skipping #{document.relative_path}: #{url} already belongs to another file"
        nil
      end
    end
  end
end

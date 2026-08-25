# frozen_string_literal: true

require "jekyll"
require_relative "configuration"

module Jekyll
  module AgentMarkdown
    class DocumentHeader
      URL_REQUIRED_MESSAGE =
        "url is required for agent_markdown document headers; it must be an absolute HTTP(S) URL " \
        "without credentials, a query, or a fragment"

      def initialize(site, relative_url)
        @site = site
        @relative_url = relative_url
      end

      def prepend_to(document, body)
        entries = ["# #{title(document)}"]
        description = one_line(document.data["description"])
        entries << description if description
        entries << "Source: #{html_url(document)}"
        "#{entries.join("\n\n")}\n\n---\n\n#{body}"
      end

      def html_url(document)
        validate_site_url!(document)
        "#{site.config["url"].to_s.sub(%r{/+\z}, "")}#{relative_url.call(document.url)}"
      end

      private

      attr_reader :site, :relative_url

      def title(document)
        one_line(document.data["title"]) || one_line(basename(document)) || "Document"
      end

      def basename(document)
        return document.basename_without_ext if document.respond_to?(:basename_without_ext)

        document.basename
      end

      def one_line(value)
        return unless value.is_a?(String)

        normalized = value.gsub(/\s+/, " ").strip
        normalized unless normalized.empty?
      end

      def validate_site_url!(document)
        return if Configuration.absolute_http_url?(site.config["url"])

        raise Jekyll::Errors::FatalException, "#{document.relative_path}: #{URL_REQUIRED_MESSAGE}"
      end
    end
  end
end

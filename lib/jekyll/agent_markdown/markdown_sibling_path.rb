# frozen_string_literal: true

require "jekyll"

module Jekyll
  module AgentMarkdown
    class MarkdownSiblingPath
      def self.for(document_url)
        new(document_url).to_s
      end

      def initialize(document_url)
        @document_url = document_url.to_s
      end

      def to_s
        normalized = path_without_output_suffix
        return "/index.md" if normalized.empty?

        "#{normalized}.md"
      end

      private

      def path_without_output_suffix
        path = canonical_url
        return path.sub(%r{/index\.html?\z}i, "") if path.match?(%r{/index\.html?\z}i)
        return path.sub(%r{/\z}, "") if path.end_with?("/")

        path.sub(/\.html?\z/i, "")
      end

      def canonical_url
        Jekyll::URL.escape_path(Jekyll::URL.unescape_path(@document_url))
      end
    end
  end
end

# frozen_string_literal: true

module Jekyll
  module AgentMarkdown
    module LlmsText
      MARKDOWN_CHARACTERS = /[\\\[\]()*_~`<>!#|]/

      module_function

      def one_line(value) = value ? value.to_s.gsub(/\s+/, " ").strip : ""

      def literal(value)
        one_line(value).gsub("&", "&amp;").gsub(MARKDOWN_CHARACTERS) { |character| "\\#{character}" }
      end

      def link_title(source_document)
        title = source_document.data.fetch("title", basename(source_document))
        one_line(title.to_s).gsub(/[\\\[\]]/) { |character| "\\#{character}" }
      end

      def basename(source_document)
        return source_document.basename_without_ext if source_document.respond_to?(:basename_without_ext)

        source_document.basename
      end

      def escaped_link_url(url) = url.gsub("(", "%28").gsub(")", "%29")
    end
  end
end

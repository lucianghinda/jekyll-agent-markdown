# frozen_string_literal: true

require_relative "llms_text"

module Jekyll
  module AgentMarkdown
    class AuthorMetadata
      def initialize(config)
        @config = config
      end

      def to_s
        author_name = name
        author_name.empty? ? "" : "Author: #{author_name}"
      end

      private

      attr_reader :config

      def name
        author = config["author"]
        author = author["name"] || author[:name] if author.is_a?(Hash)
        LlmsText.one_line(author)
      end
    end
  end
end

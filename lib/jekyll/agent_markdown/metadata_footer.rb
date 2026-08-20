# frozen_string_literal: true

module Jekyll
  module AgentMarkdown
    class MetadataFooter
      def initialize(entries)
        @text = entries.compact.reject(&:empty?).join(" | ")
      end

      def append_to(content)
        return content if text.empty?
        return "#{text}\n" if content.empty?

        "#{content}#{separator_for(content)}---\n#{text}\n"
      end

      private

      attr_reader :text

      def separator_for(content)
        content.end_with?("\n") ? "\n" : "\n\n"
      end
    end
  end
end

# frozen_string_literal: true

require_relative "configuration"

module Jekyll
  module AgentMarkdown
    class LlmsHeadings
      def initialize(site, settings)
        @site = site
        @settings = settings
      end

      def to_s
        [title_heading, description_heading, author_heading, "## Articles", articles_description]
          .compact.join("\n\n")
      end

      private

      attr_reader :site, :settings

      def title_heading = "# #{one_line(site.config.fetch("title", ""))}".rstrip

      def description_heading
        description = one_line(site.config["description"])
        "> #{description}" unless description.empty?
      end

      def author_heading
        return unless Configuration.enabled?(settings, "include_author")

        name = author_name
        "Author: #{name}" unless name.empty?
      end

      def author_name
        author = site.config["author"]
        author = author["name"] || author[:name] if author.is_a?(Hash)
        one_line(author)
      end

      def articles_description = "> Posts only. Pages and collections are not included."

      def one_line(value) = value ? value.to_s.gsub(/\s+/, " ").strip : ""
    end
  end
end

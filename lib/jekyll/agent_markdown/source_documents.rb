# frozen_string_literal: true

require "jekyll"
require_relative "configuration"

module Jekyll
  module AgentMarkdown
    class SourceDocuments
      include Enumerable

      def initialize(site, settings, collection_validator:)
        @site = site
        @settings = settings
        @collection_validator = collection_validator
      end

      def each
        return enum_for(__method__) unless block_given?

        posts.each { |document| yield document, :post, nil }
        pages.each { |document| yield document, :page, nil }
        collections.each { |document, collection_name| yield document, :collection, collection_name }
      end

      private

      attr_reader :site, :settings, :collection_validator

      def posts
        return [] unless Configuration.enabled?(settings, "posts")

        site.posts.docs
      end

      def pages
        return [] unless Configuration.enabled?(settings, "pages")

        site.pages.select { |page| authored_markdown_page?(page) }
      end

      def collections
        Configuration.collection_names(settings).flat_map do |collection_name|
          collection_validator.collection!(collection_name).docs.filter_map do |document|
            [document, collection_name] if markdown_document?(document) && document.write?
          end
        end
      end

      def authored_markdown_page?(page)
        page.is_a?(Jekyll::Page) &&
          File.file?(site.in_source_dir(page.relative_path)) &&
          markdown_extension?(page.ext)
      end

      def markdown_document?(document)
        document.is_a?(Jekyll::Document) && markdown_extension?(document.extname)
      end

      def markdown_extension?(extension)
        site.config.fetch("markdown_ext").split(",").any? do |markdown_extension|
          ".#{markdown_extension.strip.downcase}" == extension.to_s.downcase
        end
      end
    end
  end
end

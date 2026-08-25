# frozen_string_literal: true

require "jekyll"

module Jekyll
  module AgentMarkdown
    class CollectionValidator
      def initialize(site)
        @site = site
      end

      def validate!(collection_names)
        collection_names.each { |collection_name| collection!(collection_name) }
      end

      def collection!(collection_name)
        collection = site.collections[collection_name]
        return collection if collection&.write? && valid_document_urls?(collection, collection_name)

        raise_collection_error(collection, collection_name)
      end

      private

      attr_reader :site

      def valid_document_urls?(collection, collection_name)
        collection.docs.all? do |document|
          !markdown_document?(document) || public_url?(document, collection_name)
        end
      end

      def markdown_document?(document)
        document.is_a?(Jekyll::Document) && markdown_extension?(document.extname)
      end

      def markdown_extension?(extension)
        site.config.fetch("markdown_ext").split(",").any? do |markdown_extension|
          ".#{markdown_extension.strip.downcase}" == extension.to_s.downcase
        end
      end

      def public_url?(document, collection_name)
        url = document.url
        return true if url.is_a?(String) && url.start_with?("/") && !url.start_with?("//")

        public_url_error(document, collection_name)
      rescue Jekyll::Errors::FatalException
        raise
      rescue StandardError => e
        public_url_error(document, collection_name, e.message)
      end

      def public_url_error(document, collection_name, detail = nil)
        message = "#{document.relative_path}: configured collection #{collection_name.inspect} " \
                  "cannot produce a public document URL"
        message = "#{message} (#{detail})" if detail
        raise Jekyll::Errors::FatalException,
              message
      end

      def raise_collection_error(collection, collection_name)
        if collection.nil?
          raise Jekyll::Errors::FatalException,
                "agent_markdown.collections includes #{collection_name.inspect}, but that collection does not exist"
        end

        raise Jekyll::Errors::FatalException,
              "agent_markdown.collections includes #{collection_name.inspect}, but its output is disabled"
      end
    end
  end
end

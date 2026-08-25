# frozen_string_literal: true

require "jekyll"
require_relative "author_metadata"
require_relative "collection_validator"
require_relative "configuration"
require_relative "date_metadata"
require_relative "destination_claims"
require_relative "document_exporter"
require_relative "llms_full_renderer"
require_relative "llms_headings"
require_relative "llms_index_renderer"
require_relative "llms_document_ordering"
require_relative "metadata_footer"
require_relative "source_documents"

module Jekyll
  module AgentMarkdown
    class Generator < Jekyll::Generator
      include Jekyll::Filters::URLFilters

      LLMS_TXT_URL_REQUIRED_MESSAGE =
        "url is required for agent_markdown.llms_txt and must be an absolute HTTP(S) URL " \
        "without credentials, a query, or a fragment"
      LLMS_FULL_TXT_URL_REQUIRED_MESSAGE =
        "url is required for agent_markdown.llms_full_txt and must be an absolute HTTP(S) URL " \
        "without credentials, a query, or a fragment"
      ONE_MEBIBYTE = 1_048_576

      # Run after normal- and high-priority generators so their post changes are exported.
      # Destination claims therefore cover only what Jekyll knows at this point; a
      # generator declaring `priority :lowest` runs later and can still claim the
      # same destination. Jekyll offers no hook to detect that from here.
      priority :low

      attr_reader :exported_documents

      def generate(site)
        settings = Configuration.for(site)
        return if settings == false

        @exported_documents = exported_documents_for(site, settings)
        write_llms_txt(site, settings, exported_documents, @destination_claims)
        write_llms_full_txt(site, settings, exported_documents, @destination_claims)
      end

      private

      def exported_documents_for(site, settings)
        @context = Liquid::Context.new({}, {}, { site: site })
        collection_validator = CollectionValidator.new(site)
        collection_validator.validate!(Configuration.collection_names(settings))
        @destination_claims = destination_claims(site)
        exporter = DocumentExporter.new(
          site, settings, @destination_claims, content_for_post: ->(post) { post_content(site, post, settings) }
        )
        source_documents(site, settings, collection_validator).filter_map do |document, source_kind, collection_name|
          exporter.export(document, source_kind:, collection_name:)
        end
      end

      def source_documents(site, settings, collection_validator)
        SourceDocuments.new(site, settings, collection_validator:)
      end

      def destination_claims(site)
        DestinationClaims.new(site.dest).tap do |claims|
          site.each_site_file { |item| claims.add_existing(item.destination(site.dest)) }
        end
      end

      def write_llms_txt(site, settings, documents, destination_claims)
        return unless Configuration.enabled?(settings, "llms_txt")
        return unless llms_txt_ready?(site, settings)

        file = RawMarkdownFile.new(site, "/llms.txt", LlmsIndexRenderer.new(site, settings, documents).to_s)
        return llms_txt_collision_warning unless claim_destination?(destination_claims, site, file)

        site.static_files << file
      end

      def claim_destination?(destination_claims, site, file) = destination_claims.claim?(file.destination(site.dest))

      def llms_txt_collision_warning
        Jekyll.logger.warn "AgentMarkdown:",
                           "skipping /llms.txt: the destination already belongs to another file"
        nil
      end

      def write_llms_full_txt(site, settings, documents, destination_claims)
        return unless Configuration.enabled?(settings, "llms_full_txt")

        validate_llms_full_txt_url!(site)
        placeholder = RawMarkdownFile.new(site, "/llms-full.txt", "")
        return llms_full_txt_collision_warning unless claim_destination?(destination_claims, site, placeholder)

        content = LlmsFullRenderer.new(site, settings, documents).to_s
        warn_if_llms_full_txt_is_large(content)
        file = RawMarkdownFile.new(site, "/llms-full.txt", content)

        site.static_files << file
      end

      def validate_llms_full_txt_url!(site)
        return if Configuration.absolute_http_url?(site.config["url"])

        raise Jekyll::Errors::FatalException, LLMS_FULL_TXT_URL_REQUIRED_MESSAGE
      end

      def warn_if_llms_full_txt_is_large(content)
        return unless content.bytesize > ONE_MEBIBYTE

        Jekyll.logger.warn "AgentMarkdown:", "llms-full.txt exceeds 1 MiB; consider reducing its size"
      end

      def llms_full_txt_collision_warning
        Jekyll.logger.warn "AgentMarkdown:",
                           "skipping /llms-full.txt: the destination already belongs to another file"
        nil
      end

      # A missing url only fails the build when llms_txt was explicitly
      # configured; the default is to warn and skip so adding the gem never
      # breaks a previously green build.
      def llms_txt_ready?(site, settings)
        return true if Configuration.absolute_http_url?(site.config["url"])
        raise Jekyll::Errors::FatalException, LLMS_TXT_URL_REQUIRED_MESSAGE if settings.key?("llms_txt")

        Jekyll.logger.warn "AgentMarkdown:", "#{LLMS_TXT_URL_REQUIRED_MESSAGE}; skipping llms.txt"
        false
      end

      def post_content(site, post, settings)
        entries = []
        entries << date_metadata(post).to_s if Configuration.enabled?(settings, "include_dates")
        entries << AuthorMetadata.new(site.config).to_s if Configuration.enabled?(settings, "include_author")
        MetadataFooter.new(entries).append_to(post.content)
      end

      def date_metadata(post) = DateMetadata.new(post.data)

      # Retained for the public test seam used by existing integrations.
      def sorted_posts(posts, settings)
        LlmsDocumentOrdering.new(settings).legacy_ordered(posts) { |post| date_metadata(post).published_date }
      end
    end
  end
end

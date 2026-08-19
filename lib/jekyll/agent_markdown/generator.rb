# frozen_string_literal: true

require "jekyll"
require_relative "configuration"
require_relative "date_metadata"
require_relative "destination_claims"
require_relative "markdown_sibling_path"
require_relative "raw_markdown_file"

module Jekyll
  module AgentMarkdown
    class Generator < Jekyll::Generator
      include Jekyll::Filters::URLFilters

      URL_REQUIRED_MESSAGE =
        "url is required for agent_markdown.llms_txt and must be an absolute HTTP(S) URL " \
        "without credentials, a query, or a fragment"

      # Run after normal- and high-priority generators so their post changes are exported.
      priority :low

      def generate(site)
        settings = Configuration.for(site)
        return if settings == false

        @context = Liquid::Context.new({}, {}, { site: site })
        destination_claims = destination_claims(site)
        included_posts = export_posts(site, settings, destination_claims) if Configuration.enabled?(settings, "posts")
        write_llms_txt(site, settings, included_posts || [], destination_claims)
      end

      private

      def destination_claims(site)
        DestinationClaims.new(site.dest).tap do |claims|
          site.each_site_file { |item| claims.add_existing(item.destination(site.dest)) }
        end
      end

      def export_posts(site, settings, destination_claims)
        site.posts.docs.filter_map { |post| export_post(site, settings, destination_claims, post) }
      end

      def export_post(site, settings, destination_claims, post)
        setting = post.data.fetch("agent_markdown", true)
        setting_name = "agent_markdown in #{post.relative_path}"
        return unless Configuration.enabled_value?(setting, name: setting_name)

        file = RawMarkdownFile.new(site, MarkdownSiblingPath.for(post.url), post_content(post, settings))
        url = file.url
        return collision_warning(post, url) unless claim_destination?(destination_claims, site, file)

        post.data["agent_markdown_url"] = url
        site.static_files << file
        post
      end

      def collision_warning(post, url)
        Jekyll.logger.warn "AgentMarkdown:",
                           "skipping #{post.relative_path}: #{url} already belongs to another file"
        nil
      end

      def write_llms_txt(site, settings, posts, destination_claims)
        return unless Configuration.enabled?(settings, "llms_txt")
        return unless llms_txt_ready?(site, settings)

        file = RawMarkdownFile.new(site, "/llms.txt", llms_txt(site, posts, settings))
        return llms_txt_collision_warning unless claim_destination?(destination_claims, site, file)

        site.static_files << file
      end

      def claim_destination?(destination_claims, site, file) = destination_claims.claim?(file.destination(site.dest))

      def llms_txt_collision_warning
        Jekyll.logger.warn "AgentMarkdown:",
                           "skipping /llms.txt: the destination already belongs to another file"
        nil
      end

      # A missing url only fails the build when llms_txt was explicitly
      # configured; the default is to warn and skip so adding the gem never
      # breaks a previously green build.
      def llms_txt_ready?(site, settings)
        return true if Configuration.absolute_http_url?(site.config["url"])
        raise Jekyll::Errors::FatalException, URL_REQUIRED_MESSAGE if settings.key?("llms_txt")

        Jekyll.logger.warn "AgentMarkdown:", "#{URL_REQUIRED_MESSAGE}; skipping llms.txt"
        false
      end

      def llms_txt(site, posts, settings)
        sections = [llms_headings(site), article_links(site, posts, settings)]
        "#{sections.reject(&:empty?).join("\n\n")}\n"
      end

      def llms_headings(site)
        title = one_line(site.config.fetch("title", ""))
        headings = ["# #{title}".rstrip]
        description = one_line(site.config["description"])
        headings << "> #{description}" unless description.empty?
        headings << "## Articles"
        headings << "> Posts only. Pages and collections are not included."
        headings.join("\n\n")
      end

      def one_line(value) = value ? value.to_s.gsub(/\s+/, " ").strip : ""

      def article_links(site, posts, settings)
        site_url = site.config["url"].sub(%r{/+\z}, "")
        sorted_posts(posts, settings).map { |post| article_link(site_url, post, settings) }.join("\n")
      end

      def sorted_posts(posts, settings)
        dated, undated = posts.map { |post| [post, date_metadata(post).published_date] }.partition(&:last)
        dated.sort_by!(&:last)
        dated.reverse! if Configuration.sort_order(settings) == "desc"
        (dated + undated).map(&:first)
      end

      def article_link(site_url, post, settings)
        url = "#{site_url}#{relative_url(post.data.fetch("agent_markdown_url"))}"
        link = "- [#{link_title(post)}](#{escaped_link_url(url)})"
        return link unless Configuration.enabled?(settings, "include_dates")

        [link, date_metadata(post).to_s].reject(&:empty?).join(" | ")
      end

      def post_content(post, settings)
        return post.content unless Configuration.enabled?(settings, "include_dates")

        date_metadata(post).append_to(post.content)
      end

      def date_metadata(post) = DateMetadata.new(post.data)

      # Backslashes and square brackets would end the Markdown link text early;
      # whitespace runs (including newlines) would break the one-entry-per-line
      # format.
      def link_title(post)
        post.data.fetch("title", post.basename_without_ext)
            .to_s.gsub(/\s+/, " ").strip
            .gsub(/[\\\[\]]/) { |character| "\\#{character}" }
      end

      # Unescaped parentheses would end the Markdown link destination early.
      def escaped_link_url(url) = url.gsub("(", "%28").gsub(")", "%29")
    end
  end
end

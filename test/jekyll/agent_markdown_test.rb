# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class MarkdownSiblingPathTest < Minitest::Test
  def test_maps_document_urls_to_markdown_siblings
    {
      "/foo/" => "/foo.md",
      "/foo.html" => "/foo.md",
      "/foo.htm" => "/foo.md",
      "/foo.HTML" => "/foo.md",
      "/foo/index.html" => "/foo.md",
      "/release.html/" => "/release.html.md",
      "/foo/index.html/" => "/foo/index.html.md",
      "/foo" => "/foo.md",
      "/index.html" => "/index.md",
      "/" => "/index.md"
    }.each do |document_url, markdown_url|
      assert_equal markdown_url, Jekyll::AgentMarkdown::MarkdownSiblingPath.for(document_url)
    end
  end

  def test_represents_a_markdown_sibling_path
    path = Jekyll::AgentMarkdown::MarkdownSiblingPath.new("/articles/example/")

    assert_equal "/articles/example.md", path.to_s
  end

  def test_canonicalizes_percent_encoded_paths
    assert_equal "/existing.md", Jekyll::AgentMarkdown::MarkdownSiblingPath.for("/%65xisting/")
  end
end

class RawMarkdownFileTest < Minitest::Test
  def test_rejects_paths_that_can_escape_the_destination
    Dir.mktmpdir("jekyll-agent-markdown-file") do |source|
      site = Jekyll::Site.new(Jekyll.configuration("source" => source))

      ["/../outside.md", "/%2e%2e/outside.md", "//absolute.md"].each do |url|
        error = assert_raises(Jekyll::Errors::FatalException) do
          Jekyll::AgentMarkdown::RawMarkdownFile.new(site, url, "content")
        end

        assert_match(/unsafe generated path/i, error.message)
      end
    end
  end

  def test_has_no_invented_source_path
    Dir.mktmpdir("jekyll-agent-markdown-file") do |source|
      site = Jekyll::Site.new(Jekyll.configuration("source" => source))
      file = Jekyll::AgentMarkdown::RawMarkdownFile.new(site, "/articles/first.md", "content")

      assert_nil file.path
    end
  end

  def test_refuses_to_write_through_a_final_file_symlink
    Dir.mktmpdir("jekyll-agent-markdown-source") do |source|
      Dir.mktmpdir("jekyll-agent-markdown-destination") do |destination|
        Dir.mktmpdir("jekyll-agent-markdown-outside") do |outside|
          site = Jekyll::Site.new(Jekyll.configuration("source" => source, "destination" => destination))
          file = Jekyll::AgentMarkdown::RawMarkdownFile.new(site, "/articles/first.md", "generated")
          outside_file = File.join(outside, "outside.md")
          File.write(outside_file, "original")
          FileUtils.mkdir_p(File.join(destination, "articles"))
          File.symlink(outside_file, File.join(destination, "articles", "first.md"))

          error = assert_raises(Jekyll::Errors::FatalException) { file.write(destination) }

          assert_match(/unsafe generated destination/i, error.message)
          assert_equal "original", File.binread(outside_file)
        end
      end
    end
  end

  def test_refuses_to_write_through_a_parent_directory_symlink
    Dir.mktmpdir("jekyll-agent-markdown-source") do |source|
      Dir.mktmpdir("jekyll-agent-markdown-destination") do |destination|
        Dir.mktmpdir("jekyll-agent-markdown-outside") do |outside|
          site = Jekyll::Site.new(Jekyll.configuration("source" => source, "destination" => destination))
          file = Jekyll::AgentMarkdown::RawMarkdownFile.new(site, "/articles/first.md", "generated")
          File.symlink(outside, File.join(destination, "articles"))

          error = assert_raises(Jekyll::Errors::FatalException) { file.write(destination) }

          assert_match(/unsafe generated destination/i, error.message)
          refute_path_exists File.join(outside, "first.md")
        end
      end
    end
  end
end

class TestDateMutationGenerator < Jekyll::Generator
  priority :normal

  def generate(site)
    mutations = site.config["test_date_mutations"]
    return unless mutations

    site.posts.docs.each do |post|
      next unless mutations.key?(post.data["title"])

      post.data["date"] = mutations.fetch(post.data["title"])
    end
  end
end

class AgentMarkdownGeneratorTest < Minitest::Test
  POST_BODY = "# First heading\n\n*Raw* Markdown body.\n\n{{ site.title }}"

  def test_runs_after_generators_with_normal_or_high_priority
    assert_equal :low, Jekyll::AgentMarkdown::Generator.priority
  end

  def test_exports_posts_as_raw_markdown_and_exposes_the_url_to_liquid
    with_site do |site, destination|
      site.process

      assert_path_exists File.join(destination, "articles", "first", "index.html")
      expected_markdown = "#{POST_BODY}\n\n---\nPublished at: 2026-01-01 | Author: Example Author\n"

      assert_equal expected_markdown, File.binread(File.join(destination, "articles", "first.md"))
      refute_match(/\A---(?:\n|\z)/, File.binread(File.join(destination, "articles", "first.md")))
      refute_includes File.binread(File.join(destination, "articles", "first.md")), "<em>Raw</em>"
      assert_includes File.binread(File.join(destination, "articles", "first", "index.html")),
                      '<link rel="alternate" type="text/markdown" href="/blog/articles/first.md">'
    end
  end

  def test_empty_post_export_does_not_look_like_front_matter
    empty_post = <<~POST
      ---
      layout: post
      title: Empty article
      permalink: /articles/empty/
      ---
    POST

    with_site(extra_posts: { "2026-01-02-empty.md" => empty_post }) do |site, destination|
      site.process

      markdown = File.binread(File.join(destination, "articles", "empty.md"))

      assert_equal "Published at: 2026-01-02 | Author: Example Author\n", markdown
      refute_match(/\A---(?:\n|\z)/, markdown)
    end
  end

  def test_captures_post_content_before_liquid_rendering
    with_site do |site, destination|
      site.process

      assert_includes File.binread(File.join(destination, "articles", "first.md")), "{{ site.title }}"
      assert_includes File.binread(File.join(destination, "articles", "first", "index.html")),
                      "Example Site"
    end
  end

  def test_skips_posts_that_opt_out
    with_site(extra_posts: { "2026-01-02-hidden.md" => <<~POST }) do |site, destination|
      ---
      layout: post
      title: Hidden article
      permalink: /articles/hidden/
      agent_markdown: false
      ---
      # Hidden
    POST
      site.process

      refute_path_exists File.join(destination, "articles", "hidden.md")
      refute_includes File.binread(File.join(destination, "llms.txt")), "Hidden article"
    end
  end

  def test_generates_llms_txt_with_absolute_markdown_urls
    with_site do |site, destination|
      site.process

      assert_equal <<~TEXT, File.binread(File.join(destination, "llms.txt"))
        # Example Site

        > A short description

        Author: Example Author

        ## Articles

        > Posts only. Pages and collections are not included.

        - [First article](https://example.test/blog/articles/first.md) | Published at: 2026-01-01
      TEXT
    end
  end

  def test_includes_the_name_from_an_author_mapping
    with_site(config: { "author" => { "name" => "Example\nAuthor" } }) do |site, destination|
      site.process

      assert_includes File.binread(File.join(destination, "llms.txt")), "Author: Example Author"
      assert_includes File.binread(File.join(destination, "articles", "first.md")),
                      "Published at: 2026-01-01 | Author: Example Author"
    end
  end

  def test_can_disable_author_metadata
    [false, "off"].each do |value|
      config = { "agent_markdown" => { "include_author" => value } }

      with_site(config: config) do |site, destination|
        site.process

        refute_includes File.binread(File.join(destination, "llms.txt")), "Author:"
        markdown = File.binread(File.join(destination, "articles", "first.md"))

        assert_includes markdown, "Published at: 2026-01-01"
        refute_includes markdown, "Author:"
      end
    end
  end

  def test_omits_author_metadata_when_the_site_has_no_author_name
    [nil, false, {}, { "twitter" => "example" }].each do |author|
      with_site(config: { "author" => author }) do |site, destination|
        site.process

        refute_includes File.binread(File.join(destination, "llms.txt")), "Author:"
        refute_includes File.binread(File.join(destination, "articles", "first.md")), "Author:"
      end
    end
  end

  def test_includes_an_updated_date_when_the_post_provides_one
    updated_post = <<~POST
      ---
      layout: post
      title: Updated article
      permalink: /articles/updated/
      last_modified_at: 2026-02-03
      ---
      # Updated article
    POST

    with_site(extra_posts: { "2026-01-02-updated.md" => updated_post }) do |site, destination|
      site.process

      date_metadata = "Published at: 2026-01-02 | Updated at: 2026-02-03"
      article_metadata = "#{date_metadata} | Author: Example Author"

      assert_includes File.binread(File.join(destination, "articles", "updated.md")),
                      "---\n#{article_metadata}\n"
      assert_includes File.binread(File.join(destination, "llms.txt")),
                      "- [Updated article](https://example.test/blog/articles/updated.md) | #{date_metadata}"
    end
  end

  def test_omits_an_updated_date_when_the_post_does_not_provide_one
    with_site do |site, destination|
      site.process

      refute_includes File.binread(File.join(destination, "articles", "first.md")), "Updated at:"
      refute_includes File.binread(File.join(destination, "llms.txt")), "Updated at:"
    end
  end

  def test_can_disable_date_metadata
    config = { "agent_markdown" => { "include_dates" => false } }

    with_site(config: config) do |site, destination|
      site.process

      assert_equal "#{POST_BODY}\n\n---\nAuthor: Example Author\n",
                   File.binread(File.join(destination, "articles", "first.md"))
      assert_includes File.binread(File.join(destination, "llms.txt")),
                      "- [First article](https://example.test/blog/articles/first.md)\n"
      refute_includes File.binread(File.join(destination, "llms.txt")), "Published at:"
    end
  end

  def test_can_disable_both_date_and_author_metadata
    config = { "agent_markdown" => { "include_dates" => false, "include_author" => false } }

    with_site(config: config) do |site, destination|
      site.process

      assert_equal "#{POST_BODY}\n", File.binread(File.join(destination, "articles", "first.md"))
    end
  end

  def test_sorts_articles_by_published_date_ascending
    later_post = post("Later article", "/articles/later/")
    config = { "agent_markdown" => { "sort" => "asc" } }

    with_site(config: config, extra_posts: { "2026-01-03-later.md" => later_post }) do |site, destination|
      site.process

      llms_txt = File.binread(File.join(destination, "llms.txt"))

      assert_operator llms_txt.index("First article"), :<, llms_txt.index("Later article")
    end
  end

  def test_sorts_articles_by_published_date_descending
    later_post = post("Later article", "/articles/later/")
    config = { "agent_markdown" => { "sort" => "desc" } }

    with_site(config: config, extra_posts: { "2026-01-03-later.md" => later_post }) do |site, destination|
      site.process

      llms_txt = File.binread(File.join(destination, "llms.txt"))

      assert_operator llms_txt.index("Later article"), :<, llms_txt.index("First article")
    end
  end

  def test_sorts_articles_descending_by_default
    later_post = post("Later article", "/articles/later/")

    with_site(extra_posts: { "2026-01-03-later.md" => later_post }) do |site, destination|
      site.process

      llms_txt = File.binread(File.join(destination, "llms.txt"))

      assert_operator llms_txt.index("Later article"), :<, llms_txt.index("First article")
    end
  end

  def test_sorts_dates_normalized_after_an_earlier_generator_mutates_post_data
    posts = {
      "2026-01-02-february.md" => post("February article", "/articles/february/"),
      "2026-01-03-october.md" => post("October article", "/articles/october/")
    }
    config = {
      "agent_markdown" => { "sort" => "asc" },
      "test_date_mutations" => {
        "February article" => "2026-2-1",
        "October article" => "2026-10-01"
      }
    }

    with_site(config: config, extra_posts: posts) do |site, destination|
      site.process

      llms_txt = File.binread(File.join(destination, "llms.txt"))
      expected_link = "February article](https://example.test/blog/articles/february.md) | " \
                      "Published at: 2026-02-01"

      assert_order llms_txt, "First article", "February article", "October article"
      assert_includes llms_txt, expected_link
    end
  end

  def test_lists_invalid_dates_last_in_their_existing_order
    posts = {
      "2026-01-02-undated.md" => post("Undated article", "/articles/undated/"),
      "2026-01-03-invalid.md" => post("Invalid-date article", "/articles/invalid-date/")
    }
    config = {
      "test_date_mutations" => {
        "Undated article" => "",
        "Invalid-date article" => "not a date"
      }
    }

    with_site(config: config, extra_posts: posts) do |site, destination|
      site.process

      llms_txt = File.binread(File.join(destination, "llms.txt"))

      assert_order llms_txt, "First article", "Undated article", "Invalid-date article"
      refute_match(/Undated article.*Published at:/, llms_txt)
      refute_match(/Invalid-date article.*Published at:/, llms_txt)
    end
  end

  def test_lists_posts_without_dates_last_in_their_existing_order
    post = Struct.new(:data)
    first_undated = post.new({})
    dated = post.new({ "date" => Time.utc(2026, 1, 1) })
    second_undated = post.new({ "date" => nil })

    sorted = Jekyll::AgentMarkdown::Generator.new.send(
      :sorted_posts,
      [first_undated, dated, second_undated],
      { "sort" => "desc" }
    )

    assert_equal [dated, first_undated, second_undated], sorted
  end

  def test_generates_absolute_urls_when_baseurl_is_nil
    with_site(config: { "baseurl" => nil }) do |site, destination|
      site.process

      assert_includes File.binread(File.join(destination, "llms.txt")),
                      "(https://example.test/articles/first.md)"
    end
  end

  def test_requires_an_absolute_http_url_when_llms_txt_is_explicitly_enabled
    [nil, "", "/relative", "ftp://example.test"].each do |url|
      config = { "url" => url, "agent_markdown" => { "llms_txt" => true } }
      error = assert_raises(Jekyll::Errors::FatalException) do
        with_site(config: config) { |site| site.process }
      end

      assert_match(/url.*required.*agent_markdown\.llms_txt/i, error.message)
    end
  end

  def test_rejects_configured_urls_with_credentials_a_query_or_a_fragment
    [
      "https://user:secret@example.test",
      "https://example.test?preview=1",
      "https://example.test/#articles"
    ].each do |url|
      config = { "url" => url, "agent_markdown" => { "llms_txt" => true } }

      error = assert_raises(Jekyll::Errors::FatalException) do
        with_site(config: config) { |site| site.process }
      end

      assert_match(/url.*required.*agent_markdown\.llms_txt/i, error.message)
    end
  end

  def test_skips_llms_txt_but_keeps_post_markdown_when_url_is_missing_by_default
    with_site(config: { "url" => "" }) do |site, destination|
      site.process

      refute_path_exists File.join(destination, "llms.txt")
      assert_path_exists File.join(destination, "articles", "first.md")
    end
  end

  def test_strips_extra_trailing_slashes_from_the_configured_url
    with_site(config: { "url" => "https://example.test//" }) do |site, destination|
      site.process

      assert_includes File.binread(File.join(destination, "llms.txt")),
                      "(https://example.test/blog/articles/first.md)"
    end
  end

  def test_escapes_markdown_link_syntax_in_titles_and_urls
    extra_posts = { "2026-01-02-tricky.md" => post("Using [] and (parens)", "/articles/br(ackets)/") }

    with_site(extra_posts: extra_posts) do |site, destination|
      site.process

      assert_includes File.binread(File.join(destination, "llms.txt")),
                      "- [Using \\[\\] and (parens)](https://example.test/blog/articles/br%28ackets%29.md)"
    end
  end

  def test_normalizes_multiline_llms_txt_headings
    config = {
      "title" => "Example\n# Injected heading",
      "description" => "First line\n\n## Injected description"
    }

    with_site(config: config) do |site, destination|
      site.process

      llms_txt = File.binread(File.join(destination, "llms.txt"))

      assert_includes llms_txt, "# Example # Injected heading"
      assert_includes llms_txt, "> First line ## Injected description"
      refute_match(/^# Injected heading$/, llms_txt)
      refute_match(/^## Injected description$/, llms_txt)
    end
  end

  def test_treats_false_title_and_description_as_absent
    with_site(config: { "title" => false, "description" => false }) do |site, destination|
      site.process

      llms_txt = File.binread(File.join(destination, "llms.txt"))

      assert_match(/\A#\n\nAuthor: Example Author\n\n## Articles/, llms_txt)
      refute_includes llms_txt, "false"
    end
  end

  def test_generated_static_files_expose_root_relative_urls_and_build_time_mtime
    with_site do |site, _destination|
      site.process

      exported = site.static_files.grep(Jekyll::AgentMarkdown::RawMarkdownFile)

      assert_equal ["/articles/first.md", "/llms.txt"], exported.map(&:url).sort
      exported.each do |file|
        assert_equal site.time, file.modified_time
        assert_equal site.time, file.to_liquid["modified_time"]
      end
    end
  end

  def test_warns_and_skips_when_two_posts_map_to_the_same_markdown_sibling
    extra_posts = {
      "2026-01-02-dir.md" => post("Dir permalink", "/articles/foo/"),
      "2026-01-03-file.md" => post("File permalink", "/articles/foo.html")
    }

    with_site(extra_posts: extra_posts) do |site, destination|
      messages = messages_logged { site.process }

      assert_includes File.binread(File.join(destination, "articles", "foo.md")), "Dir permalink"
      llms_txt = File.binread(File.join(destination, "llms.txt"))

      assert_includes llms_txt, "Dir permalink"
      refute_includes llms_txt, "File permalink"
      assert_includes messages.join("\n"), "/articles/foo.md already belongs to another file"
    end
  end

  def test_does_not_clobber_an_existing_static_file
    extra_posts = { "2026-01-02-clash.md" => post("Clashing post", "/existing/") }
    extra_files = { "existing.md" => "original static file\n" }

    with_site(extra_posts: extra_posts, extra_files: extra_files) do |site, destination|
      site.process

      assert_equal "original static file\n", File.binread(File.join(destination, "existing.md"))
      refute_includes File.binread(File.join(destination, "llms.txt")), "Clashing post"
    end
  end

  def test_does_not_clobber_an_existing_static_file_through_an_encoded_alias
    extra_posts = { "2026-01-02-clash.md" => post("Clashing post", "/%65xisting/") }
    extra_files = { "existing.md" => "original static file\n" }

    with_site(extra_posts: extra_posts, extra_files: extra_files) do |site, destination|
      site.process

      assert_equal "original static file\n", File.binread(File.join(destination, "existing.md"))
      refute_includes File.binread(File.join(destination, "llms.txt")), "Clashing post"
    end
  end

  def test_does_not_clobber_an_existing_static_file_through_a_case_only_alias
    extra_posts = { "2026-01-02-clash.md" => post("Clashing post", "/existing/") }
    extra_files = { "EXISTING.md" => "original static file\n" }

    with_site(extra_posts: extra_posts, extra_files: extra_files) do |site, destination|
      site.process

      assert_equal "original static file\n", File.binread(File.join(destination, "EXISTING.md"))
      refute_includes File.binread(File.join(destination, "llms.txt")), "Clashing post"
    end
  end

  def test_does_not_clobber_an_existing_static_file_through_a_unicode_alias
    extra_posts = { "2026-01-02-clash.md" => post("Clashing post", "/cafe\u0301/") }
    extra_files = { "caf\u00e9.md" => "original static file\n" }

    with_site(extra_posts: extra_posts, extra_files: extra_files) do |site, destination|
      site.process

      assert_equal "original static file\n", File.binread(File.join(destination, "caf\u00e9.md"))
      refute_includes File.binread(File.join(destination, "llms.txt")), "Clashing post"
    end
  end

  def test_skips_a_generated_file_when_the_destination_is_an_existing_directory
    extra_posts = { "2026-01-02-clash.md" => post("Clashing post", "/existing/") }
    extra_files = { "existing.md/info.txt" => "directory owner\n" }

    with_site(extra_posts: extra_posts, extra_files: extra_files) do |site, destination|
      site.process

      assert_equal "directory owner\n", File.binread(File.join(destination, "existing.md", "info.txt"))
      refute_includes File.binread(File.join(destination, "llms.txt")), "Clashing post"
    end
  end

  def test_resolves_generated_file_and_directory_conflicts_first_writer_wins
    extra_posts = {
      "2026-01-02-parent.md" => post("Parent export", "/generated/"),
      "2026-01-03-child.md" => post("Child export", "/generated.md/child/")
    }

    with_site(extra_posts: extra_posts) do |site, destination|
      site.process

      assert_includes File.binread(File.join(destination, "generated.md", "child.md")), "Child export"
      llms_txt = File.binread(File.join(destination, "llms.txt"))

      assert_includes llms_txt, "Child export"
      refute_includes llms_txt, "Parent export"
    end
  end

  def test_does_not_clobber_a_page_destination
    extra_posts = { "2026-01-02-clash.md" => post("Clashing post", "/articles/reserved/") }
    extra_files = { "pages/reserved.md" => authored_document("Authored page", "/articles/reserved.md") }

    with_site(extra_posts: extra_posts, extra_files: extra_files) do |site, destination|
      site.process

      assert_includes File.binread(File.join(destination, "articles", "reserved.md")), "Authored page"
      refute_includes File.binread(File.join(destination, "llms.txt")), "Clashing post"
    end
  end

  def test_does_not_advertise_a_collection_document_destination_as_an_export
    extra_posts = { "2026-01-02-clash.md" => post("Clashing post", "/articles/reserved/") }
    extra_files = { "_notes/reserved.md" => authored_document("Authored note", "/articles/reserved.md") }
    config = { "collections" => { "notes" => { "output" => true } } }

    with_site(config: config, extra_posts: extra_posts, extra_files: extra_files) do |site, destination|
      site.process

      assert_includes File.binread(File.join(destination, "articles", "reserved.md")), "Authored note"
      refute_includes File.binread(File.join(destination, "llms.txt")), "Clashing post"
    end
  end

  def test_does_not_clobber_an_existing_llms_txt
    with_site(extra_files: { "llms.txt" => "author supplied\n" }) do |site, destination|
      site.process

      assert_equal "author supplied\n", File.binread(File.join(destination, "llms.txt"))
    end
  end

  def test_skips_llms_txt_when_that_destination_is_an_existing_directory
    with_site(extra_files: { "llms.txt/info.txt" => "directory owner\n" }) do |site, destination|
      site.process

      assert_equal "directory owner\n", File.binread(File.join(destination, "llms.txt", "info.txt"))
    end
  end

  def test_generated_files_ignore_published_false_frontmatter_defaults
    defaults = [{ "scope" => { "path" => "articles" }, "values" => { "published" => false } }]

    with_site(config: { "defaults" => defaults }) do |site, destination|
      site.process

      assert_path_exists File.join(destination, "articles", "first.md")
      assert_includes File.binread(File.join(destination, "llms.txt")), "First article"
    end
  end

  def test_non_writeable_static_files_do_not_reserve_destinations
    defaults = [{ "scope" => { "path" => "existing.md" }, "values" => { "published" => false } }]
    extra_posts = { "2026-01-02-clash.md" => post("Generated post", "/existing/") }

    with_site(
      config: { "defaults" => defaults },
      extra_posts: extra_posts,
      extra_files: { "existing.md" => "not published\n" }
    ) do |site, destination|
      site.process

      assert_includes File.binread(File.join(destination, "existing.md")), "Generated post"
      assert_includes File.binread(File.join(destination, "llms.txt")), "Generated post"
    end
  end

  def test_rewrites_markdown_on_incremental_build_when_a_page_has_the_same_source_path
    page = <<~PAGE
      ---
      title: Unrelated page
      ---
      Unrelated page body.
    PAGE

    options = { config: { "incremental" => true }, extra_files: { "articles/first.md" => page } }

    with_site(**options) do |site, destination, source|
      site.process
      post_path = File.join(source, "_posts", "2026-01-01-first.md")
      File.write(post_path, File.binread(post_path).sub(POST_BODY, "Changed raw body."))

      site.process

      assert_includes File.binread(File.join(destination, "articles", "first.md")), "Changed raw body."
    end
  end

  def test_exports_html_bare_and_root_permalinks_at_mapped_sibling_paths
    extra_posts = {
      "2026-01-02-html.md" => post("HTML permalink", "/articles/foo.html"),
      "2026-01-03-bare.md" => post("Bare permalink", "/articles/bare"),
      "2026-01-04-root.md" => post("Root permalink", "/")
    }

    with_site(extra_posts: extra_posts) do |site, destination|
      site.process

      assert_path_exists File.join(destination, "articles", "foo.md")
      assert_path_exists File.join(destination, "articles", "bare.md")
      assert_path_exists File.join(destination, "index.md")
      assert_equal "/articles/foo.md", post_with_title(site, "HTML permalink").data["agent_markdown_url"]
      assert_equal "/articles/bare.md", post_with_title(site, "Bare permalink").data["agent_markdown_url"]
      assert_equal "/index.md", post_with_title(site, "Root permalink").data["agent_markdown_url"]
    end
  end

  def test_honors_post_and_llms_txt_flags
    with_site(config: { "agent_markdown" => { "posts" => false, "llms_txt" => false } }) do |site, destination|
      site.process

      refute_path_exists File.join(destination, "articles", "first.md")
      refute_path_exists File.join(destination, "llms.txt")
    end
  end

  def test_disabling_llms_txt_keeps_post_markdown
    with_site(config: { "agent_markdown" => { "llms_txt" => false } }) do |site, destination|
      site.process

      assert_path_exists File.join(destination, "articles", "first.md")
      refute_path_exists File.join(destination, "llms.txt")
    end
  end

  def test_false_style_strings_opt_posts_out
    posts = {
      "2026-01-02-false.md" => opted_out_post("False string", "/articles/false/", "false"),
      "2026-01-03-no.md" => opted_out_post("No string", "/articles/no/", "no"),
      "2026-01-04-off.md" => opted_out_post("Off string", "/articles/off/", "off")
    }

    with_site(extra_posts: posts) do |site, destination|
      site.process

      %w[false no off].each do |slug|
        refute_path_exists File.join(destination, "articles", "#{slug}.md")
        refute_includes File.binread(File.join(destination, "llms.txt")), "#{slug.capitalize} string"
      end
    end
  end

  def test_false_top_level_configuration_disables_all_exports
    with_site(config: { "agent_markdown" => false }) do |site, destination|
      site.process

      refute_path_exists File.join(destination, "articles", "first.md")
      refute_path_exists File.join(destination, "llms.txt")
    end
  end

  def test_nil_top_level_configuration_uses_default_exports
    with_site(config: { "agent_markdown" => nil }) do |site, destination|
      site.process

      assert_path_exists File.join(destination, "articles", "first.md")
      assert_path_exists File.join(destination, "llms.txt")
    end
  end

  def test_true_top_level_configuration_uses_default_exports
    with_site(config: { "agent_markdown" => true }) do |site, destination|
      site.process

      assert_path_exists File.join(destination, "articles", "first.md")
      assert_path_exists File.join(destination, "llms.txt")
    end
  end

  def test_rejects_non_mapping_top_level_configuration
    error = assert_raises(Jekyll::Errors::FatalException) do
      with_site(config: { "agent_markdown" => "enabled" }) { |site| site.process }
    end

    assert_match(/agent_markdown.*Hash, true, or false/i, error.message)
  end

  def test_rejects_unknown_configuration_keys
    error = assert_raises(Jekyll::Errors::FatalException) do
      with_site(config: { "agent_markdown" => { "post" => false } }) { |site| site.process }
    end

    assert_match(/unknown agent_markdown setting: post/i, error.message)
  end

  def test_rejects_invalid_nested_configuration_values
    [
      %w[posts flase],
      ["llms_txt", 0],
      %w[include_dates sometimes],
      ["include_author", 0],
      ["posts", {}],
      ["llms_txt", []]
    ].each do |setting, value|
      error = assert_raises(Jekyll::Errors::FatalException) do
        with_site(config: { "agent_markdown" => { setting => value } }) { |site| site.process }
      end

      assert_match(/agent_markdown\.#{setting}.*true.*false/i, error.message)
    end
  end

  def test_rejects_an_invalid_sort_order
    error = assert_raises(Jekyll::Errors::FatalException) do
      with_site(config: { "agent_markdown" => { "sort" => "newest" } }) { |site| site.process }
    end

    assert_match(/agent_markdown\.sort.*asc.*desc/i, error.message)
  end

  def test_rejects_invalid_per_post_configuration_values
    ["flase", 0, {}, []].each_with_index do |value, index|
      name = format("2026-01-%02d-invalid.md", index + 2)
      posts = { name => post_with_agent_markdown("Invalid post setting", "/invalid-#{index}/", value) }

      error = assert_raises(Jekyll::Errors::FatalException) do
        with_site(extra_posts: posts) { |site| site.process }
      end

      assert_match(%r{agent_markdown.*_posts/#{Regexp.escape(name)}.*true.*false}i, error.message)
    end
  end

  def test_generates_an_empty_article_list_when_no_posts_are_included
    with_site(config: { "agent_markdown" => { "posts" => false } }) do |site, destination|
      site.process

      assert_equal <<~TEXT, File.binread(File.join(destination, "llms.txt"))
        # Example Site

        > A short description

        Author: Example Author

        ## Articles

        > Posts only. Pages and collections are not included.
      TEXT
    end
  end

  private

  def with_site(config: {}, extra_posts: {}, extra_files: {})
    Dir.mktmpdir("jekyll-agent-markdown") do |source|
      destination = File.join(source, "_site")
      write_source_file(source, "_config.yml", base_config.merge(config).to_yaml)
      extra_files.each { |name, content| write_source_file(source, name, content) }
      write_source_file(source, "_layouts/post.html", <<~LIQUID)
        <!doctype html>
        {% if page.agent_markdown_url %}
        <link rel="alternate" type="text/markdown" href="{{ page.agent_markdown_url | relative_url }}">
        {% endif %}
        {{ content }}
      LIQUID
      write_source_file(source, "_posts/2026-01-01-first.md", <<~POST)
        ---
        layout: post
        title: First article
        permalink: /articles/first/
        ---
        #{POST_BODY}
      POST
      extra_posts.each { |name, content| write_source_file(source, File.join("_posts", name), content) }

      site = Jekyll::Site.new(Jekyll.configuration("source" => source, "destination" => destination))
      yield site, destination, source
    end
  end

  def base_config
    {
      "title" => "Example Site",
      "description" => "A short description",
      "author" => "Example Author",
      "url" => "https://example.test/",
      "baseurl" => "/blog/",
      "markdown" => "kramdown"
    }
  end

  def post(title, permalink)
    <<~POST
      ---
      layout: post
      title: #{title.inspect}
      permalink: #{permalink.inspect}
      ---
      # #{title}
    POST
  end

  def opted_out_post(title, permalink, value)
    <<~POST
      ---
      layout: post
      title: #{title}
      permalink: #{permalink}
      agent_markdown: "#{value}"
      ---
      # #{title}
    POST
  end

  def post_with_agent_markdown(title, permalink, value)
    <<~POST
      ---
      layout: post
      title: #{title.inspect}
      permalink: #{permalink.inspect}
      agent_markdown: #{value.inspect}
      ---
      # #{title}
    POST
  end

  def authored_document(title, permalink)
    <<~DOCUMENT
      ---
      title: #{title.inspect}
      permalink: #{permalink.inspect}
      ---
      # #{title}
    DOCUMENT
  end

  def messages_logged
    offset = Jekyll.logger.messages.length
    yield
    Jekyll.logger.messages.drop(offset)
  end

  def assert_order(content, *items)
    positions = items.map { |item| content.index(item) }

    assert_predicate positions, :all?, "expected every item to appear in #{content.inspect}"
    assert_equal positions.sort, positions
  end

  def write_source_file(source, name, content)
    path = File.join(source, name)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def post_with_title(site, title)
    site.posts.docs.find { |post| post.data["title"] == title }
  end
end

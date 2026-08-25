# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "yaml"

class AgentMarkdownLinkTagTest < Minitest::Test
  LINK_TAG = "agent_markdown_link"

  def test_renders_one_baseurl_aware_alternate_link_for_an_exported_post
    assert_tag_registered

    with_site do |_site, destination|
      assert_equal alternate_link("/blog/articles/first.md"), output_at(destination, "articles/first/index.html")
    end
  end

  def test_renders_one_alternate_link_for_an_exported_page
    assert_tag_registered

    with_site do |_site, destination|
      assert_equal alternate_link("/blog/about.md"), output_at(destination, "about/index.html")
    end
  end

  def test_renders_one_alternate_link_for_an_exported_collection_document
    assert_tag_registered

    with_site do |_site, destination|
      assert_equal alternate_link("/blog/guides/first.md"), output_at(destination, "guides/first/index.html")
    end
  end

  def test_renders_an_empty_string_when_the_current_document_was_not_exported
    assert_tag_registered

    with_site do |_site, destination|
      assert_empty output_at(destination, "private/index.html")
    end
  end

  def test_html_escapes_the_exported_markdown_url
    assert_tag_registered

    with_site do |_site, destination|
      assert_equal alternate_link("/blog/research&amp;notes.md"),
                   output_at(destination, "research&notes/index.html")
    end
  end

  private

  def assert_tag_registered
    refute_nil Liquid::Template.tags[LINK_TAG], "expected #{LINK_TAG.inspect} to be registered"
  end

  def with_site
    Dir.mktmpdir("jekyll-agent-markdown-link-tag") do |source|
      destination = File.join(source, "_site")
      write_site(source)
      site = Jekyll::Site.new(Jekyll.configuration("source" => source, "destination" => destination))

      site.process

      yield site, destination
    end
  end

  def write_site(source)
    write_file(source, "_config.yml", site_config.to_yaml)
    write_file(source, "_layouts/agent.html", "{% agent_markdown_link %}")
    write_file(source, "_posts/2026-01-01-first.md", document("First post", "/articles/first/"))
    write_file(source, "about.md", document("About", "/about/"))
    write_file(source, "_guides/first.md", document("First guide", "/guides/first/"))
    write_file(source, "private.md", document("Private", "/private/", agent_markdown: false))
    write_file(source, "research.md", document("Research", "/research&notes/"))
  end

  def write_file(source, relative_path, content)
    path = File.join(source, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def site_config
    {
      "url" => "https://example.test",
      "baseurl" => "/blog",
      "collections" => { "guides" => { "output" => true } },
      "agent_markdown" => {
        "pages" => true,
        "collections" => ["guides"],
        "llms_txt" => false
      }
    }
  end

  def document(title, permalink, agent_markdown: nil)
    front_matter = { "layout" => "agent", "title" => title, "permalink" => permalink }
    front_matter["agent_markdown"] = agent_markdown unless agent_markdown.nil?
    "---\n#{front_matter.to_yaml.delete_prefix("---\n")}---\nBody\n"
  end

  def alternate_link(url)
    %(<link rel="alternate" type="text/markdown" href="#{url}">)
  end

  def output_at(destination, relative_path)
    File.binread(File.join(destination, relative_path))
  end
end

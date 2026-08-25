# frozen_string_literal: true

require "test_helper"
require "yaml"

module DocumentationContract
  ROOT = File.expand_path("..", __dir__)
  GLOBAL_DEFAULTS = %w[
    posts
    pages
    collections
    llms_txt
    llms_full_txt
    include_descriptions
    include_document_header
    include_author
    include_dates
    sort
  ].freeze
  DOC_SELECTION_TERMS = [
    "pages", "Markdown", "collections", "export", "index", "section", "optional",
    "include_document_header", "invalid", "llms.txt", "llms-full", "1 MiB",
    "agent_markdown_url", "agent_markdown_link", "collision"
  ].freeze
  LIMITATION_TERMS = [
    "deployment.md", "no automatic injection", "negotiation", "crawler policy",
    "analytics", "middleware", "raw Markdown"
  ].freeze

  private

  def read(path)
    File.binread(File.join(ROOT, path))
  end

  def assert_order(text, *needles)
    position = -1
    needles.each do |needle|
      index = text.index(needle)

      assert index, "missing #{needle.inspect}"
      assert_operator index, :>, position, "#{needle.inspect} is out of order"
      position = index
    end
  end

  def assert_includes_all(text, needles)
    needles.each { |needle| assert_includes text, needle }
  end

  def fenced_blocks(text, language)
    text.scan(/^```#{language}\n(.*?)^```$/m).flatten
  end
end

class ReadmeDocumentationContractTest < Minitest::Test
  include DocumentationContract

  def test_uses_the_expected_section_order
    assert_order read("README.md"),
                 "# jekyll-agent-markdown", "## Installation", "## Quick Start", "## Usage",
                 "## Options", "## Deployment", "## Compatibility", "## Development", "## License"
  end

  def test_documents_the_global_defaults_and_scalar_compatibility
    readme = read("README.md")

    assert_includes_all readme, GLOBAL_DEFAULTS
    assert_includes readme, "true"
    assert_includes readme, "false"
    assert_includes readme, "case-insensitive"
  end

  def test_configuration_examples_parse_and_defaults_match_the_implementation
    examples = fenced_blocks(read("README.md"), "yaml")
    documented_defaults = YAML.safe_load(examples.last).fetch("agent_markdown")

    examples.each { |example| assert_kind_of Hash, YAML.safe_load(example) }
    assert_equal Jekyll::AgentMarkdown::Configuration::DEFAULTS, documented_defaults
  end

  def test_documents_source_eligibility_and_front_matter
    readme = read("README.md")

    assert_includes_all readme, DOC_SELECTION_TERMS
    assert_includes readme, "Posts export by default"
    assert_includes readme, "Markdown-backed pages"
    assert_includes readme, "non-output collection fails"
    assert_includes readme, "public document URL fails"
    refute_includes readme, "skips non-output collections"
  end

  def test_documents_valid_placement_and_liquid_examples
    readme = read("README.md")

    assert_includes readme, "section: Documentation"
    assert_includes readme, "optional: false"
    assert_includes readme, "{% agent_markdown_link %}"
    assert_includes readme, "1 MiB"
    fenced_blocks(readme, "liquid").each { |example| Liquid::Template.parse(example) }
  end

  def test_documents_url_validation_and_collision_consequences
    readme = read("README.md")

    assert_includes readme, "without credentials, a query, or a fragment"
    assert_includes readme, "missing or invalid"
    assert_includes readme, "posts, then pages, then configured collections"
    assert_includes readme, "receive no `agent_markdown_url`"
    assert_includes readme, "omitted from both indexes"
  end

  def test_documents_the_boundary_of_the_collision_guarantee
    readme = read("README.md")

    assert_includes readme, "priority :low"
    assert_includes readme, "priority :lowest"
  end

  def test_documents_compatibility_and_limitations
    readme = read("README.md")

    assert_includes_all readme, LIMITATION_TERMS
    assert_includes readme, "byte-for-byte"
    assert_includes readme, "Ruby 3.2"
    assert_includes readme, "Jekyll 4.3"
  end
end

class ReleaseDocumentationContractTest < Minitest::Test
  include DocumentationContract

  def test_changelog_describes_the_latest_release
    changelog = read("CHANGELOG.md")

    assert_match(/\A## \[#{Regexp.escape(Jekyll::AgentMarkdown::VERSION)}\] - \d{4}-\d{2}-\d{2}$/, changelog)
    assert_match(/- .*Export.*pages.*collections/i, changelog)
    assert_match(/- .*llms\.txt.*llms-full\.txt/i, changelog)
    assert_match(/- .*agent_markdown_link.*agent_markdown_url/i, changelog)
    assert_match(/- .*Cloudflare.*Netlify.*nginx/i, changelog)
  end

  def test_gemspec_summary_and_description_cover_the_current_scope
    gemspec = read("jekyll-agent-markdown.gemspec")

    assert_includes gemspec, 'spec.summary = "'
    assert_includes gemspec, 'spec.description = "'
    refute_includes gemspec, "post Markdown available alongside rendered HTML"
    refute_includes gemspec, "post Markdown"
  end
end

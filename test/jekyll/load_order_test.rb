# frozen_string_literal: true

require "test_helper"
require "open3"

class LoadOrderTest < Minitest::Test
  IMPLEMENTATION_FEATURES = %w[
    jekyll/agent_markdown/agent_markdown_link_tag
    jekyll/agent_markdown/author_metadata
    jekyll/agent_markdown/configuration
    jekyll/agent_markdown/collection_validator
    jekyll/agent_markdown/date_metadata
    jekyll/agent_markdown/destination_claims
    jekyll/agent_markdown/document_exporter
    jekyll/agent_markdown/document_header
    jekyll/agent_markdown/document_settings
    jekyll/agent_markdown/exported_document
    jekyll/agent_markdown/llms_document_index
    jekyll/agent_markdown/llms_document_ordering
    jekyll/agent_markdown/llms_full_renderer
    jekyll/agent_markdown/llms_headings
    jekyll/agent_markdown/llms_index_renderer
    jekyll/agent_markdown/llms_text
    jekyll/agent_markdown/markdown_sibling_path
    jekyll/agent_markdown/metadata_footer
    jekyll/agent_markdown/raw_markdown_file
    jekyll/agent_markdown/source_documents
    jekyll/agent_markdown/generator
    jekyll/agent_markdown/version
  ].freeze

  def test_exposes_the_release_version
    assert_equal "0.4.0", Jekyll::AgentMarkdown::VERSION
  end

  def test_implementation_files_can_be_required_directly
    IMPLEMENTATION_FEATURES.each do |feature|
      stderr, status = require_in_subprocess(feature)

      assert_predicate status, :success?, "require #{feature.inspect} failed:\n#{stderr}"
    end
  end

  def test_destination_claims_can_be_instantiated_after_a_direct_require
    feature = "jekyll/agent_markdown/destination_claims"
    expression = "Jekyll::AgentMarkdown::DestinationClaims.new(Dir.pwd)"
    stderr, status = require_in_subprocess(feature, expression)

    assert_predicate status, :success?, "instantiate after require #{feature.inspect} failed:\n#{stderr}"
  end

  def test_source_documents_direct_require_loads_its_configuration_dependency
    feature = "jekyll/agent_markdown/source_documents"
    expression = "raise unless defined?(Jekyll::AgentMarkdown::Configuration)"
    stderr, status = require_in_subprocess(feature, expression)

    assert_predicate status, :success?, "require #{feature.inspect} failed:\n#{stderr}"
  end

  def test_direct_require_of_the_tag_does_not_register_it
    feature = "jekyll/agent_markdown/agent_markdown_link_tag"
    expression = 'raise if Liquid::Template.tags["agent_markdown_link"]'
    stderr, status = require_in_subprocess(feature, expression)

    assert_predicate status, :success?, "direct require registered the tag:\n#{stderr}"
  end

  def test_public_entrypoint_registers_the_tag
    feature = "jekyll-agent-markdown"
    expression = <<~RUBY.delete("\n")
      expected = Jekyll::AgentMarkdown::AgentMarkdownLinkTag;
      actual = Liquid::Template.tags["agent_markdown_link"];
      raise unless actual == expected
    RUBY
    stderr, status = require_in_subprocess(feature, expression)

    assert_predicate status, :success?, "public entrypoint did not register the tag:\n#{stderr}"
  end

  private

  def require_in_subprocess(feature, expression = nil)
    source = ["require #{feature.inspect}", expression].compact.join("; ")
    _stdout, stderr, status = Open3.capture3(
      { "RUBYOPT" => nil },
      Gem.ruby,
      "-I#{File.expand_path("../../lib", __dir__)}",
      "-e",
      source
    )
    [stderr, status]
  end
end

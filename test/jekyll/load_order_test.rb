# frozen_string_literal: true

require "test_helper"
require "open3"

class LoadOrderTest < Minitest::Test
  IMPLEMENTATION_FEATURES = %w[
    jekyll/agent_markdown/author_metadata
    jekyll/agent_markdown/configuration
    jekyll/agent_markdown/date_metadata
    jekyll/agent_markdown/destination_claims
    jekyll/agent_markdown/llms_headings
    jekyll/agent_markdown/markdown_sibling_path
    jekyll/agent_markdown/metadata_footer
    jekyll/agent_markdown/raw_markdown_file
    jekyll/agent_markdown/generator
    jekyll/agent_markdown/version
  ].freeze

  def test_exposes_the_release_version
    assert_equal "0.3.1", Jekyll::AgentMarkdown::VERSION
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

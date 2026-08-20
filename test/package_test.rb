# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class PackageTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  GEMSPEC = File.join(ROOT, "jekyll-agent-markdown.gemspec")
  EXPECTED_FILES = %w[
    lib/jekyll-agent-markdown.rb
    lib/jekyll/agent_markdown/author_metadata.rb
    lib/jekyll/agent_markdown/generator.rb
    lib/jekyll/agent_markdown/llms_headings.rb
    lib/jekyll/agent_markdown/metadata_footer.rb
    README.md
    LICENSE.txt
  ].freeze

  def test_gemspec_files_do_not_depend_on_the_callers_working_directory
    specification = Dir.mktmpdir("jekyll-agent-markdown-package") do |directory|
      Dir.chdir(directory) { Gem::Specification.load(GEMSPEC) }
    end

    assert_empty EXPECTED_FILES - specification.files
  end
end

# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class PackageTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  GEMSPEC = File.join(ROOT, "jekyll-agent-markdown.gemspec")

  def test_gemspec_files_do_not_depend_on_the_callers_working_directory
    specification = Dir.mktmpdir("jekyll-agent-markdown-package") do |directory|
      Dir.chdir(directory) { Gem::Specification.load(GEMSPEC) }
    end

    assert_includes specification.files, "lib/jekyll-agent-markdown.rb"
    assert_includes specification.files, "lib/jekyll/agent_markdown/generator.rb"
    assert_includes specification.files, "README.md"
    assert_includes specification.files, "LICENSE.txt"
  end
end

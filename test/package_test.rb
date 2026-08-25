# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class PackageTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  GEMSPEC = File.join(ROOT, "jekyll-agent-markdown.gemspec")
  EXPECTED_FILES = %w[
    docs/deployment.md
    examples/cloudflare/src/worker.js
    examples/cloudflare/wrangler.toml
    examples/netlify/netlify.toml
    examples/netlify/netlify/edge-functions/markdown-negotiation.ts
    examples/nginx/negotiation.js
    examples/nginx/nginx.conf
    lib/jekyll-agent-markdown.rb
    lib/jekyll/agent_markdown/agent_markdown_link_tag.rb
    lib/jekyll/agent_markdown/author_metadata.rb
    lib/jekyll/agent_markdown/configuration.rb
    lib/jekyll/agent_markdown/document_settings.rb
    lib/jekyll/agent_markdown/exported_document.rb
    lib/jekyll/agent_markdown/generator.rb
    lib/jekyll/agent_markdown/llms_document_index.rb
    lib/jekyll/agent_markdown/llms_document_ordering.rb
    lib/jekyll/agent_markdown/llms_full_renderer.rb
    lib/jekyll/agent_markdown/llms_headings.rb
    lib/jekyll/agent_markdown/llms_index_renderer.rb
    lib/jekyll/agent_markdown/llms_text.rb
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

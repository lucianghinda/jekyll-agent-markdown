# frozen_string_literal: true

require_relative "lib/jekyll/agent_markdown/version"

Gem::Specification.new do |spec|
  spec.name = "jekyll-agent-markdown"
  spec.version = Jekyll::AgentMarkdown::VERSION
  spec.authors = ["Lucian Ghinda"]
  spec.email = ["lucian@ghinda.com"]

  spec.summary = "Exports Jekyll content as Markdown siblings and llms.txt"
  spec.description = "A Jekyll plugin that exports posts, pages, and output collections as " \
                     "Markdown siblings plus curated llms.txt and llms-full.txt files."
  spec.homepage = "https://github.com/lucianghinda/jekyll-agent-markdown"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/main"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    Dir[
      "lib/**/*.rb",
      "docs/deployment.md",
      "examples/**/*",
      "LICENSE.txt",
      "README.md",
      "CHANGELOG.md"
    ]
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "jekyll", ">= 4.3", "< 5"
end

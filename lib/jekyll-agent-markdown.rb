# frozen_string_literal: true

require "jekyll"
require_relative "jekyll/agent_markdown/version"
require_relative "jekyll/agent_markdown/generator"
require_relative "jekyll/agent_markdown/agent_markdown_link_tag"

Liquid::Template.register_tag("agent_markdown_link", Jekyll::AgentMarkdown::AgentMarkdownLinkTag)

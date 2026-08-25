# frozen_string_literal: true

require "cgi"
require "jekyll"

module Jekyll
  module AgentMarkdown
    class AgentMarkdownLinkTag < Liquid::Tag
      include Jekyll::Filters::URLFilters

      def render(context)
        @context = context
        markdown_url = context["page"]&.[]("agent_markdown_url")
        return "" unless markdown_url

        %(<link rel="alternate" type="text/markdown" href="#{CGI.escapeHTML(relative_url(markdown_url))}">)
      end
    end
  end
end

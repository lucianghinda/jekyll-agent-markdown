# frozen_string_literal: true

module Jekyll
  module AgentMarkdown
    ExportedDocument = Data.define(
      :source_document,
      :source_kind,
      :markdown_url,
      :markdown_content,
      :body,
      :html_url,
      :section,
      :index,
      :optional
    )
  end
end

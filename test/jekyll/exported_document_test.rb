# frozen_string_literal: true

require "test_helper"

class ExportedDocumentTest < Minitest::Test
  ATTRIBUTES = {
    source_kind: :post,
    markdown_url: "/articles/example.md",
    markdown_content: "# Example\n",
    body: "# Example\n",
    html_url: "/articles/example/",
    section: "Articles",
    index: true,
    optional: false
  }.freeze

  def test_is_an_immutable_record_for_the_document_export_contract
    document = Object.new
    attributes = ATTRIBUTES.merge(source_document: document)
    exported_document = Jekyll::AgentMarkdown::ExportedDocument.new(**attributes)

    assert_equal attributes, exported_document.to_h
    assert_predicate exported_document, :frozen?
  end
end

# frozen_string_literal: true

require "test_helper"

class LlmsDocumentIndexTest < Minitest::Test
  Collection = Struct.new(:label)
  SourceDocument = Struct.new(:data, :collection)

  def setup
    @documents = [
      exported_document(:post),
      exported_document(:page, section: "Guides"),
      exported_document(:page, optional: true),
      exported_document(:collection, collection_name: "guides")
    ]
    @calls = Hash.new(0).compare_by_identity
    @index = Jekyll::AgentMarkdown::LlmsDocumentIndex.new({ "pages" => true, "collections" => ["guides"] }, @documents)
    @index.singleton_class.prepend(resolution_counter(@calls))
  end

  def test_resolves_each_document_once_and_caches_section_results
    assert_sections_are_cached
    assert_each_document_was_resolved_once
  end

  def test_optional_section_is_last_when_a_collection_uses_the_reserved_name
    documents = [
      exported_document(:collection, collection_name: "optional"),
      exported_document(:collection, collection_name: "guides")
    ]
    index = Jekyll::AgentMarkdown::LlmsDocumentIndex.new(
      { "collections" => %w[optional guides] }, documents
    )

    assert_equal %w[Guides Optional], index.sections.map(&:name)
  end

  private

  def assert_sections_are_cached
    assert_same @index.sections, @index.sections
  end

  def assert_each_document_was_resolved_once
    assert_equal @documents.length, @calls.length
    assert_equal [1], @calls.values.uniq
  end

  def exported_document(source_kind, section: nil, optional: false, collection_name: nil)
    Jekyll::AgentMarkdown::ExportedDocument.new(
      source_document: SourceDocument.new({}, collection_name && Collection.new(collection_name)), source_kind:,
      markdown_url: "/document.md",
      markdown_content: "", body: "", html_url: "/document/", section:, index: true, optional:
    )
  end

  def resolution_counter(calls)
    Module.new do
      define_method(:resolved_section_key) do |document|
        calls[document] += 1
        super(document)
      end
    end
  end
end

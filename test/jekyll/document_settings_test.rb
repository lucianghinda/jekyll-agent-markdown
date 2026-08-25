# frozen_string_literal: true

require "test_helper"

# This keeps the related inheritance and validation contract in one focused file.
# rubocop:disable Metrics/ClassLength
class DocumentSettingsTest < Minitest::Test
  Document = Struct.new(:data, :relative_path)
  MAPPING_OVERRIDE = {
    "index" => false,
    "section" => "Guides",
    "include_document_header" => true
  }.freeze

  def test_inherits_enabled_post_defaults
    settings = Jekyll::AgentMarkdown::Configuration.for(Struct.new(:config).new({ "agent_markdown" => nil }))
    document_settings = for_document({}, settings: settings)

    assert_predicate document_settings, :export?
    assert_predicate document_settings, :index?
    refute_predicate document_settings, :optional?
    refute_predicate document_settings, :include_document_header?
    assert_nil document_settings.section
  end

  def test_global_source_exclusion_cannot_be_overridden_by_document_metadata
    settings = { "pages" => false, "include_document_header" => true }
    document_settings = for_document(
      { "agent_markdown" => { "export" => true, "index" => true, "include_document_header" => false } },
      settings: settings,
      source_kind: :page
    )

    refute_predicate document_settings, :export?
    refute_predicate document_settings, :index?
    refute_predicate document_settings, :include_document_header?
  end

  def test_global_source_exclusion_does_not_make_index_metadata_invalid
    document_settings = for_document(
      { "agent_markdown" => { "index" => true } },
      settings: { "pages" => false },
      source_kind: :page
    )

    refute_predicate document_settings, :export?
    refute_predicate document_settings, :index?
  end

  def test_collection_inclusion_is_inherited_from_the_global_allowlist
    included = for_document({}, settings: { "collections" => ["guides"] }, source_kind: :collection,
                                collection_name: "guides")
    excluded = for_document({}, settings: { "collections" => ["guides"] }, source_kind: :collection,
                                collection_name: "news")

    assert_predicate included, :export?
    assert_predicate included, :index?
    refute_predicate excluded, :export?
    refute_predicate excluded, :index?
  end

  def test_collection_inclusion_uses_canonicalized_global_names
    site = Struct.new(:config).new({ "agent_markdown" => { "collections" => [" guides "] } })
    settings = Jekyll::AgentMarkdown::Configuration.for(site)
    document_settings = for_document({}, settings: settings, source_kind: :collection,
                                         collection_name: "guides")

    assert_predicate document_settings, :export?
    assert_predicate document_settings, :index?
  end

  def test_rejects_unsupported_source_kinds_with_the_document_path
    error = assert_raises(Jekyll::Errors::FatalException) do
      for_document({}, source_kind: :static_file)
    end

    assert_match(%r{_posts/example\.md}, error.message)
    assert_match(/unsupported source kind/i, error.message)
  end

  def test_rejects_missing_or_empty_collection_names_with_the_document_path
    [nil, "", "  "].each do |collection_name|
      error = assert_raises(Jekyll::Errors::FatalException) do
        for_document({}, source_kind: :collection, collection_name: collection_name)
      end

      assert_match(%r{_posts/example\.md}, error.message)
      assert_match(/collection_name.*non-empty/i, error.message)
    end
  end

  def test_normalizes_false_style_document_settings_as_an_opt_out
    [false, "false", "no", "off"].each do |value|
      document_settings = for_document({ "agent_markdown" => value })

      refute_predicate document_settings, :export?
      refute_predicate document_settings, :index?
    end
  end

  def test_applies_document_mapping_overrides_on_top_of_global_defaults
    document_settings = for_document(
      { "agent_markdown" => MAPPING_OVERRIDE },
      settings: { "include_document_header" => false }
    )

    assert_predicate document_settings, :export?
    refute_predicate document_settings, :index?
    assert_equal "Guides", document_settings.section
    assert_predicate document_settings, :include_document_header?
  end

  def test_export_false_also_disables_index
    document_settings = for_document({ "agent_markdown" => { "export" => false } })

    refute_predicate document_settings, :export?
    refute_predicate document_settings, :index?
  end

  def test_optional_documents_are_grouped_under_optional
    document_settings = for_document({ "agent_markdown" => { "optional" => true } })

    assert_predicate document_settings, :optional?
    assert_equal "Optional", document_settings.section
  end

  def test_rejects_unknown_document_mapping_keys_with_the_document_path
    error = assert_raises(Jekyll::Errors::FatalException) do
      for_document({ "agent_markdown" => { "missing" => true } })
    end

    assert_match(%r{_posts/example\.md}, error.message)
    assert_match(/unknown agent_markdown setting: missing/i, error.message)
  end

  def test_rejects_invalid_document_boolean_values_with_the_document_path
    error = assert_raises(Jekyll::Errors::FatalException) do
      for_document({ "agent_markdown" => { "export" => "sometimes" } })
    end

    assert_match(%r{_posts/example\.md}, error.message)
    assert_match(/agent_markdown\.export.*true.*false/i, error.message)
  end

  def test_rejects_index_true_when_export_is_false
    error = assert_raises(Jekyll::Errors::FatalException) do
      for_document({ "agent_markdown" => { "export" => false, "index" => true } })
    end

    assert_match(%r{_posts/example\.md}, error.message)
    assert_match(/export.*false.*index.*true/i, error.message)
  end

  def test_rejects_optional_with_an_explicit_section
    error = assert_raises(Jekyll::Errors::FatalException) do
      for_document({ "agent_markdown" => { "optional" => true, "section" => "Guides" } })
    end

    assert_match(%r{_posts/example\.md}, error.message)
    assert_match(/optional.*section/i, error.message)
  end

  def test_rejects_empty_or_non_string_sections_with_the_document_path
    ["", "  ", 1, nil].each do |section|
      error = assert_raises(Jekyll::Errors::FatalException) do
        for_document({ "agent_markdown" => { "section" => section } })
      end

      assert_match(%r{_posts/example\.md}, error.message)
      assert_match(/agent_markdown\.section/i, error.message)
    end
  end

  def test_normalizes_section_whitespace_to_a_single_safe_line
    document_settings = for_document({ "agent_markdown" => { "section" => " Guides\n\t## injected " } })

    assert_equal "Guides ## injected", document_settings.section
  end

  private

  def for_document(data, settings: {}, source_kind: :post, collection_name: nil)
    document = Document.new(data, "_posts/example.md")
    Jekyll::AgentMarkdown::DocumentSettings.new(
      document,
      settings,
      source_kind: source_kind,
      collection_name: collection_name
    )
  end
end
# rubocop:enable Metrics/ClassLength

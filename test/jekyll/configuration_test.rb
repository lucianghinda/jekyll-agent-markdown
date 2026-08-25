# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  Site = Struct.new(:config)
  DEFAULTS = {
    "posts" => true,
    "pages" => false,
    "collections" => [],
    "llms_txt" => true,
    "llms_full_txt" => false,
    "include_descriptions" => false,
    "include_document_header" => false,
    "include_author" => true,
    "include_dates" => true,
    "sort" => "desc"
  }.freeze
  ALL_SETTINGS = DEFAULTS.merge(
    "posts" => false,
    "pages" => true,
    "collections" => ["guides"],
    "llms_txt" => "no",
    "llms_full_txt" => true,
    "include_descriptions" => true,
    "include_document_header" => true,
    "include_author" => false,
    "include_dates" => "off",
    "sort" => "asc"
  ).freeze
  BOOLEAN_SETTINGS = %w[
    posts pages llms_txt llms_full_txt include_descriptions
    include_document_header include_author include_dates
  ].freeze

  def test_exposes_all_global_defaults
    assert_equal DEFAULTS, Jekyll::AgentMarkdown::Configuration.defaults
  end

  # Configuration.for uses false as a public disabled sentinel.
  # rubocop:disable Minitest/RefuteFalse
  def test_preserves_legacy_scalar_configuration_behavior
    assert_equal({}, configuration_for(nil))
    assert_equal({}, configuration_for(true))
    assert_equal false, configuration_for(false)
    assert_equal false, configuration_for(" OFF ")
  end
  # rubocop:enable Minitest/RefuteFalse

  def test_accepts_every_global_setting
    settings = configuration_for(ALL_SETTINGS)

    assert_equal [false, true, false, true, true, true, false, false], enabled_values(settings)
    assert_equal [["guides"], "asc"], [
      Jekyll::AgentMarkdown::Configuration.collection_names(settings),
      Jekyll::AgentMarkdown::Configuration.sort_order(settings)
    ]
  end

  def test_rejects_unknown_global_mapping_keys
    error = assert_raises(Jekyll::Errors::FatalException) { configuration_for("unexpected" => true) }

    assert_match(/unknown agent_markdown setting: unexpected/i, error.message)
  end

  def test_rejects_invalid_boolean_global_values
    BOOLEAN_SETTINGS.each do |key|
      error = assert_raises(Jekyll::Errors::FatalException) { configuration_for(key => "sometimes") }

      assert_match(/agent_markdown\.#{key}.*true.*false/i, error.message)
    end
  end

  def test_rejects_a_non_array_collections_value
    error = assert_raises(Jekyll::Errors::FatalException) { configuration_for("collections" => "guides") }

    assert_match(/agent_markdown\.collections.*Array/i, error.message)
  end

  def test_rejects_duplicate_collection_names
    error = assert_raises(Jekyll::Errors::FatalException) { configuration_for("collections" => %w[guides guides]) }

    assert_match(/agent_markdown\.collections.*unique/i, error.message)
  end

  def test_canonicalizes_collection_names_before_returning_them
    settings = configuration_for("collections" => [" guides "])

    assert_equal ["guides"], Jekyll::AgentMarkdown::Configuration.collection_names(settings)
  end

  def test_rejects_unknown_enabled_setting_keys
    assert_raises(KeyError) { Jekyll::AgentMarkdown::Configuration.enabled?({}, "unknown") }
  end

  def test_rejects_empty_or_non_string_collection_names
    [[""], ["  "], [nil], [1]].each do |collections|
      error = assert_raises(Jekyll::Errors::FatalException) { configuration_for("collections" => collections) }

      assert_match(/agent_markdown\.collections/i, error.message)
    end
  end

  private

  def configuration_for(agent_markdown)
    Jekyll::AgentMarkdown::Configuration.for(Site.new({ "agent_markdown" => agent_markdown }))
  end

  def enabled_values(settings)
    BOOLEAN_SETTINGS.map { |key| Jekyll::AgentMarkdown::Configuration.enabled?(settings, key) }
  end
end

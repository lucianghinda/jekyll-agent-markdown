# frozen_string_literal: true

require "test_helper"

class DateMetadataTest < Minitest::Test
  def test_formats_each_available_date_and_omits_missing_dates
    published = Jekyll::AgentMarkdown::DateMetadata.new("date" => Time.utc(2026, 1, 2))
    updated = Jekyll::AgentMarkdown::DateMetadata.new(
      "last_modified_at" => "2026-02-03T14:30:00+02:00"
    )

    assert_equal "Published at: 2026-01-02", published.to_s
    assert_equal "Updated at: 2026-02-03", updated.to_s
  end

  def test_normalizes_a_date_with_non_padded_components
    metadata = Jekyll::AgentMarkdown::DateMetadata.new("date" => "2026-2-1")

    assert_equal Date.new(2026, 2, 1), metadata.published_date
    assert_equal "Published at: 2026-02-01", metadata.to_s
  end

  def test_is_empty_when_neither_date_exists
    metadata = Jekyll::AgentMarkdown::DateMetadata.new({})

    assert_empty metadata.to_s
    assert_equal "Article body", metadata.append_to("Article body")
  end

  def test_omits_an_unparseable_date
    metadata = Jekyll::AgentMarkdown::DateMetadata.new("date" => "not a date")

    assert_empty metadata.to_s
  end

  def test_omits_a_date_without_an_explicit_year
    metadata = Jekyll::AgentMarkdown::DateMetadata.new("date" => "March 2")

    assert_nil metadata.published_date
    assert_empty metadata.to_s
  end

  def test_appends_metadata_after_the_article_body
    metadata = Jekyll::AgentMarkdown::DateMetadata.new("date" => "2026-01-02")

    assert_equal "Article body\n\n---\nPublished at: 2026-01-02\n", metadata.append_to("Article body")
    assert_equal "Published at: 2026-01-02\n", metadata.append_to("")
    refute_match(/\A---(?:\n|\z)/, metadata.append_to(""))
  end
end

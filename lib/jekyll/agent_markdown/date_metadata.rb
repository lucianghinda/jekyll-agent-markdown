# frozen_string_literal: true

require "date"
require_relative "metadata_footer"

module Jekyll
  module AgentMarkdown
    class DateMetadata
      DATE_FORMAT = "%Y-%m-%d"
      FIELDS = {
        "Published at" => "date",
        "Updated at" => "last_modified_at"
      }.freeze
      REQUIRED_DATE_PARTS = %i[year mon mday].freeze

      def initialize(data)
        @data = data
      end

      def to_s
        @to_s ||= FIELDS.filter_map { |label, key| entry(label, @data[key]) }.join(" | ")
      end

      def append_to(content)
        MetadataFooter.new([to_s]).append_to(content)
      end

      def published_date = parsed_date(@data["date"])

      private

      def entry(label, value)
        date = formatted_date(value)
        "#{label}: #{date}" if date
      end

      def formatted_date(value)
        parsed_date(value)&.strftime(DATE_FORMAT)
      end

      def parsed_date(value)
        return Date.strptime(value.strftime(DATE_FORMAT), DATE_FORMAT) if value.respond_to?(:strftime)
        return unless value.is_a?(String)

        parts = Date._parse(value, false)
        return unless REQUIRED_DATE_PARTS.all? { |part| parts.key?(part) }

        Date.new(*parts.values_at(*REQUIRED_DATE_PARTS))
      rescue Date::Error
        nil
      end
    end
  end
end

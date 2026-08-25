# frozen_string_literal: true

require_relative "configuration"

module Jekyll
  module AgentMarkdown
    class LlmsDocumentOrdering
      def initialize(settings)
        @settings = settings
      end

      def ordered(documents, &published_date)
        dated, undated = records(documents, &published_date).partition { |_document, date, _order| !date.nil? }
        dated.sort! { |left, right| compare(left, right) }
        (dated + undated).map(&:first)
      end

      def legacy_ordered(documents, &published_date)
        dated, undated = records(documents, &published_date).partition { |_document, date, _order| !date.nil? }
        dated.sort_by! { |_document, date, _order| date }
        dated.reverse! if Configuration.sort_order(settings) == "desc"
        (dated + undated).map(&:first)
      end

      private

      attr_reader :settings

      def records(documents)
        documents.each_with_index.map { |document, order| [document, yield(document), order] }
      end

      def compare(left, right)
        comparison = left[1] <=> right[1]
        comparison = -comparison if Configuration.sort_order(settings) == "desc"
        comparison.zero? ? left[2] <=> right[2] : comparison
      end
    end
  end
end

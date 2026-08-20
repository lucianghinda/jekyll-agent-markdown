# frozen_string_literal: true

require "jekyll"
require "uri"

module Jekyll
  module AgentMarkdown
    class Configuration
      ALLOWED_SETTINGS = %w[include_author include_dates llms_txt posts sort].freeze
      FALSE_STRINGS = %w[false no off].freeze
      SORT_ORDERS = %w[asc desc].freeze

      class << self
        def for(site)
          settings = site.config["agent_markdown"]
          return {} if settings.nil? || settings == true
          return false if disabled?(settings)

          unless settings.is_a?(Hash)
            raise Jekyll::Errors::FatalException, "agent_markdown must be a Hash, true, or false"
          end

          normalized_settings(settings)
        end

        def enabled?(settings, key)
          !disabled?(settings.fetch(key, true))
        end

        def sort_order(settings)
          settings.fetch("sort", "desc")
        end

        def enabled_value?(value, name:)
          validate_value!(name, value)
          !disabled?(value)
        end

        def disabled?(value)
          value == false || (value.is_a?(String) && FALSE_STRINGS.include?(value.strip.downcase))
        end

        def absolute_http_url?(url)
          uri = URI.parse(url) if url.is_a?(String)
          uri.is_a?(URI::HTTP) &&
            !uri.host.to_s.empty? &&
            uri.userinfo.nil? &&
            uri.query.nil? &&
            uri.fragment.nil?
        rescue URI::InvalidURIError
          false
        end

        private

        def normalized_settings(settings)
          normalized = settings.to_h { |key, value| [key.to_s, value] }
          validate_keys!(normalized)
          validate_values!(normalized)
          normalized
        end

        def validate_keys!(settings)
          unknown = settings.keys - ALLOWED_SETTINGS
          return if unknown.empty?

          suffix = "s" if unknown.length > 1
          raise Jekyll::Errors::FatalException,
                "unknown agent_markdown setting#{suffix}: #{unknown.sort.join(", ")}"
        end

        def validate_values!(settings)
          settings.each do |key, value|
            if key == "sort"
              validate_sort_order!(value)
            else
              validate_value!("agent_markdown.#{key}", value)
            end
          end
        end

        def validate_sort_order!(value)
          return if SORT_ORDERS.include?(value)

          raise Jekyll::Errors::FatalException,
                "agent_markdown.sort must be asc or desc; got #{value.inspect}"
        end

        def validate_value!(name, value)
          return if valid_value?(value)

          raise Jekyll::Errors::FatalException,
                "#{name} must be true, false, or a false-style string; got #{value.inspect}"
        end

        def valid_value?(value)
          value == true || disabled?(value)
        end
      end
    end
  end
end

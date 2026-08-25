# frozen_string_literal: true

require "jekyll"
require "uri"

module Jekyll
  module AgentMarkdown
    class Configuration
      DEFAULTS = {
        "posts" => true,
        "pages" => false,
        "collections" => [].freeze,
        "llms_txt" => true,
        "llms_full_txt" => false,
        "include_descriptions" => false,
        "include_document_header" => false,
        "include_author" => true,
        "include_dates" => true,
        "sort" => "desc"
      }.freeze
      ALLOWED_SETTINGS = DEFAULTS.keys.freeze
      FALSE_STRINGS = %w[false no off].freeze
      SORT_ORDERS = %w[asc desc].freeze

      class << self
        def defaults = DEFAULTS.dup

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
          !disabled?(settings.fetch(key, DEFAULTS.fetch(key)))
        end

        def sort_order(settings)
          settings.fetch("sort", DEFAULTS.fetch("sort"))
        end

        def collection_names(settings)
          settings.fetch("collections", DEFAULTS.fetch("collections"))
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
          normalize_values!(normalized)
          normalized
        end

        def validate_keys!(settings)
          unknown = settings.keys - ALLOWED_SETTINGS
          return if unknown.empty?

          suffix = "s" if unknown.length > 1
          raise Jekyll::Errors::FatalException,
                "unknown agent_markdown setting#{suffix}: #{unknown.sort.join(", ")}"
        end

        def normalize_values!(settings)
          settings.each do |key, value|
            case key
            when "sort"
              validate_sort_order!(value)
            when "collections"
              settings[key] = CollectionNames.normalize(value)
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

      module CollectionNames
        module_function

        def normalize(value)
          validate_array!(value)
          names = value.map { |name| normalized_name!(name) }
          validate_unique!(names)
          validate_reserved!(names)
          names
        end

        def validate_array!(value)
          return if value.is_a?(Array)

          raise Jekyll::Errors::FatalException,
                "agent_markdown.collections must be an Array of unique, non-empty collection names; " \
                "got #{value.inspect}"
        end

        def normalized_name!(name)
          return name.strip if name.is_a?(String) && !name.strip.empty?

          raise Jekyll::Errors::FatalException,
                "agent_markdown.collections must contain only non-empty collection names; got #{name.inspect}"
        end

        def validate_unique!(names)
          return if names.uniq.length == names.length

          raise Jekyll::Errors::FatalException, "agent_markdown.collections must contain unique collection names"
        end

        def validate_reserved!(names)
          return unless names.include?("posts")

          raise Jekyll::Errors::FatalException,
                "agent_markdown.collections cannot include \"posts\"; use agent_markdown.posts instead"
        end
      end
    end
  end
end

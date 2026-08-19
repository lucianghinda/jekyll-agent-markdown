# frozen_string_literal: true

require "fileutils"
require "jekyll"

module Jekyll
  module AgentMarkdown
    class RawMarkdownFile < StaticFile
      def initialize(site, url, content)
        @content = content
        path = validated_path(url)
        super(site, site.source, File.dirname(path), File.basename(path))
      end

      # In-memory files have no source path. Returning nil also makes Jekyll's
      # incremental regenerator write them on every build.
      def path
        nil
      end

      # The inherited implementation stats the source path, which never exists
      # for generated files.
      def modified_time
        @modified_time ||= @site.time
      end

      # Front-matter defaults target authored files, not plugin output.
      def write?
        true
      end

      def write(destination)
        output = self.destination(destination)
        validate_destination!(destination, output)
        FileUtils.mkdir_p(File.dirname(output))
        validate_destination!(destination, output)
        File.open(output, write_flags, 0o644) { |file| file.write(@content) }
        true
      rescue Errno::ELOOP
        raise Jekyll::Errors::FatalException, "unsafe generated destination: #{output.inspect}"
      end

      private

      # Validate a decoded copy, but keep the encoded URL for StaticFile so
      # Jekyll performs exactly one decode when it computes the destination.
      def validated_path(url)
        path = url.to_s
        decoded_path = Jekyll::URL.unescape_path(path)
        return path if root_relative?(decoded_path) && !decoded_path.split("/").include?("..")

        raise Jekyll::Errors::FatalException, "unsafe generated path: #{url.inspect}"
      end

      def root_relative?(path)
        path.start_with?("/") && !path.start_with?("//") && path != "/"
      end

      def validate_destination!(destination, output)
        root = File.expand_path(destination)
        expanded_output = File.expand_path(output)
        validate_destination_boundary!(root, expanded_output, output)
        validate_destination_symlinks!(root, expanded_output, output)
      end

      def validate_destination_boundary!(root, expanded_output, output)
        return if expanded_output.start_with?("#{root}#{File::SEPARATOR}")

        raise Jekyll::Errors::FatalException, "unsafe generated destination: #{output.inspect}"
      end

      def validate_destination_symlinks!(root, expanded_output, output)
        relative_path = expanded_output.delete_prefix("#{root}#{File::SEPARATOR}")
        current_path = root
        unsafe = relative_path.split(File::SEPARATOR).any? do |component|
          current_path = File.join(current_path, component)
          File.symlink?(current_path)
        end
        return unless unsafe

        raise Jekyll::Errors::FatalException, "unsafe generated destination: #{output.inspect}"
      end

      def write_flags
        flags = File::WRONLY | File::CREAT | File::TRUNC | File::BINARY
        return flags unless File::Constants.const_defined?(:NOFOLLOW)

        flags | File::Constants::NOFOLLOW
      end
    end
  end
end

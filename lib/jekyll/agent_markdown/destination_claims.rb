# frozen_string_literal: true

module Jekyll
  module AgentMarkdown
    class DestinationClaims
      def initialize(root)
        @root = identity(root)
        @files = Set.new
        @directories = Set.new
      end

      def add_existing(path)
        add(identity(path))
      end

      def claim?(path)
        candidate = identity(path)
        return false if conflict?(candidate)

        add(candidate)
        true
      end

      private

      def conflict?(candidate)
        @files.include?(candidate) ||
          @directories.include?(candidate) ||
          ancestors(candidate).any? { |ancestor| @files.include?(ancestor) }
      end

      def add(path)
        @files << path
        ancestors(path).each { |ancestor| @directories << ancestor }
      end

      def ancestors(path)
        parent = File.dirname(path)
        ancestors = []

        while parent != @root && inside_root?(parent)
          ancestors << parent
          parent = File.dirname(parent)
        end

        ancestors
      end

      def inside_root?(path)
        path.start_with?("#{@root}#{File::SEPARATOR}")
      end

      # Treat case and Unicode normalization aliases as collisions everywhere.
      # This preserves the same first-writer behavior across deployment filesystems.
      def identity(path)
        File.expand_path(path)
            .unicode_normalize(:nfc)
            .downcase(:fold)
            .unicode_normalize(:nfc)
      end
    end
  end
end

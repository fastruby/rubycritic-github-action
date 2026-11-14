# frozen_string_literal: true

require 'set'

module RubycriticPr
  # Finds the head-side lines of a PR that GitHub lets us comment on.
  module DiffParser
    HUNK = /\A@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@/

    module_function

    # Added and context lines of a unified-diff patch, as head line numbers.
    def commentable_lines(patch)
      lines = Set.new
      return lines if patch.nil?

      current = nil
      patch.each_line do |line|
        if (m = HUNK.match(line))
          current = m[1].to_i
          next
        end
        next if current.nil?

        case line[0]
        when '-', '\\' then next
        else
          lines << current
          current += 1
        end
      end
      lines
    end

    # files: the array returned by GET /pulls/:n/files.
    # Returns { "path/in/head.rb" => Set[line, ...] }. Deleted files are skipped.
    def commentable(files)
      files.each_with_object({}) do |file, map|
        next if file['status'] == 'removed'

        map[file['filename']] = commentable_lines(file['patch'])
      end
    end
  end
end

# frozen_string_literal: true

require 'test_helper'

class DiffParserTest < Minitest::Test
  P = RubycriticPr::DiffParser

  def test_added_and_context_lines_are_commentable_removed_are_not
    patch = "@@ -1,3 +1,3 @@\n a\n-b\n+B\n c\n"
    assert_equal [1, 2, 3], P.commentable_lines(patch).to_a.sort
  end

  def test_multiple_hunks
    patch = "@@ -1,2 +1,2 @@\n a\n+b\n@@ -20,2 +30,3 @@\n x\n+y\n+z\n"
    assert_equal [1, 2, 30, 31, 32], P.commentable_lines(patch).to_a.sort
  end

  def test_new_file
    patch = "@@ -0,0 +1,3 @@\n+a\n+b\n+c\n"
    assert_equal [1, 2, 3], P.commentable_lines(patch).to_a.sort
  end

  def test_no_newline_marker_does_not_shift_lines
    patch = "@@ -1,2 +1,2 @@\n a\n-b\n\\ No newline at end of file\n+c\n\\ No newline at end of file\n"
    assert_equal [1, 2], P.commentable_lines(patch).to_a.sort
  end

  def test_blank_context_line
    patch = "@@ -1,3 +1,3 @@\n a\n\n+c\n"
    assert_equal [1, 2, 3], P.commentable_lines(patch).to_a.sort
  end

  def test_nil_patch_has_no_lines
    assert_empty P.commentable_lines(nil)
  end

  def test_files_handles_rename_and_deleted
    files = [
      { 'filename' => 'lib/new_name.rb', 'status' => 'renamed', 'patch' => "@@ -1 +1,2 @@\n a\n+b\n" },
      { 'filename' => 'lib/gone.rb', 'status' => 'removed', 'patch' => "@@ -1 +0,0 @@\n-a\n" },
      { 'filename' => 'lib/pure_rename.rb', 'status' => 'renamed' }
    ]
    map = P.commentable(files)
    assert_equal [1, 2], map['lib/new_name.rb'].to_a.sort
    refute map.key?('lib/gone.rb')
    assert_empty map['lib/pure_rename.rb']
  end
end

# frozen_string_literal: true

require 'test_helper'

class MarkdownTest < Minitest::Test
  include Builders
  M = RubycriticPr::Markdown

  def test_inline_body_round_trips_marker
    f = finding
    assert_equal M.key_digest(f.smell), M.marker_digest(M.inline_body(f))
  end

  def test_marker_ignores_location
    a = finding(locations: [{ 'path' => 'a.rb', 'line' => 1 }])
    b = finding(locations: [{ 'path' => 'a.rb', 'line' => 99 }])
    assert_equal M.key_digest(a.smell), M.key_digest(b.smell)
  end

  def test_marker_digest_is_nil_without_marker
    assert_nil M.marker_digest('hello')
  end

  def test_summary_has_marker_and_scores
    body = M.summary(base_score: 90.0, head_score: 88.5, findings: [], listed: [])
    assert_includes body, M::SUMMARY_MARKER
    assert_includes body, '| 90.0 | 88.5 | -1.5 |'
    assert_includes body, 'No new smells'
  end

  def test_summary_table_escapes_pipes_and_labels_worse
    f = finding(kind: :worse, message: 'a | b')
    body = M.summary(base_score: 1, head_score: 1, findings: [f], listed: [f])
    assert_includes body, 'a \\| b'
    assert_includes body, '(was: has approx 12 statements)'
  end
end

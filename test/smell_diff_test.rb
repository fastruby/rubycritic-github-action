# frozen_string_literal: true

require 'test_helper'

class SmellDiffTest < Minitest::Test
  include Builders

  def diff(base, head)
    RubycriticPr::SmellDiff.call(report(smells: base).smells, report(smells: head).smells)
  end

  def test_identical_reports_have_no_new_smells
    assert_empty diff([smell], [smell])
  end

  def test_moved_smell_is_not_new
    moved = smell(locations: [{ 'path' => 'lib/foo.rb', 'line' => 40 }])
    assert_empty diff([smell], [moved])
  end

  def test_new_smell_is_new
    result = diff([], [smell])
    assert_equal [:new], result.map(&:kind)
  end

  def test_duplicate_keys_count_as_a_multiset
    dup_a = smell(locations: [{ 'path' => 'lib/a.rb', 'line' => 1 }])
    dup_b = smell(locations: [{ 'path' => 'lib/b.rb', 'line' => 1 }])
    result = diff([dup_a], [dup_a, dup_b])
    assert_equal 1, result.size
    assert_equal 'lib/b.rb', result.first.smell.locations.first[:path]
  end

  def test_changed_message_on_same_context_is_worse
    result = diff([smell(message: 'has approx 12 statements')], [smell(message: 'has approx 14 statements')])
    assert_equal [:worse], result.map(&:kind)
    assert_equal 'has approx 12 statements', result.first.previous_message
  end

  def test_changed_score_on_same_context_is_worse
    result = diff([smell(score: 3)], [smell(score: 9)])
    assert_equal [:worse], result.map(&:kind)
  end

  def test_different_context_is_new_not_worse
    result = diff([smell(context: 'Foo#a')], [smell(context: 'Foo#b')])
    assert_equal [:new], result.map(&:kind)
  end

  def test_same_smell_listed_under_two_modules_is_collapsed
    s = smell
    data = { 'score' => 1.0, 'analysed_modules' => [{ 'smells' => [s] }, { 'smells' => [s] }] }
    assert_equal 1, RubycriticPr::Report.from_hash(data).smells.size
  end
end

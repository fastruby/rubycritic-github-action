# frozen_string_literal: true

require 'test_helper'

class AnnotationsTest < Minitest::Test
  include Builders
  A = RubycriticPr::Annotations

  def test_format
    line = A.format(finding)
    assert_equal '::warning file=lib/foo.rb,line=3,title=TooManyStatements::Foo#bar has approx 14 statements', line
  end

  def test_escapes_special_characters
    assert_equal 'a%25b%0Ac', A.escape_data("a%b\nc")
    assert_equal 'a%3Ab%2Cc', A.escape_property('a:b,c')
  end

  def test_cap_reports_omitted_count
    findings = Array.new(12) { finding }
    lines, omitted = A.render(findings, cap: 10)
    assert_equal 10, lines.size
    assert_equal 2, omitted
  end

  def test_under_cap_omits_nothing
    _lines, omitted = A.render([finding])
    assert_equal 0, omitted
  end
end

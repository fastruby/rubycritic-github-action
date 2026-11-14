# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'json'
require 'stringio'
require 'rubycritic_pr'

module Builders
  def smell(context: 'Foo#bar', message: 'has approx 14 statements', score: 5, type: 'TooManyStatements',
            locations: [{ 'path' => 'lib/foo.rb', 'line' => 3 }])
    { 'context' => context, 'message' => message, 'score' => score, 'type' => type, 'locations' => locations }
  end

  def report_hash(smells: [], score: 90.0)
    { 'score' => score, 'analysed_modules' => [{ 'name' => 'Foo', 'path' => 'lib/foo.rb', 'smells' => smells }] }
  end

  def report(**opts)
    RubycriticPr::Report.from_hash(report_hash(**opts))
  end

  def finding(kind: :new, **opts)
    s = RubycriticPr::Report.from_hash(report_hash(smells: [smell(**opts)])).smells.first
    RubycriticPr::SmellDiff::Finding.new(smell: s, kind: kind, previous_message: (kind == :worse ? 'has approx 12 statements' : nil))
  end
end

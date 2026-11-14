# frozen_string_literal: true

require 'digest'
require 'json'

module RubycriticPr
  # Builds comment bodies and the hidden markers used to dedupe them.
  module Markdown
    SUMMARY_MARKER = '<!-- rubycritic-summary -->'
    INLINE_MARKER = /<!-- rubycritic:([0-9a-f]{40}) -->/

    module_function

    def key_digest(smell)
      Digest::SHA1.hexdigest(smell.key.to_json)
    end

    def inline_marker(smell)
      "<!-- rubycritic:#{key_digest(smell)} -->"
    end

    def marker_digest(body)
      INLINE_MARKER.match(body.to_s)&.[](1)
    end

    def describe(finding)
      smell = finding.smell
      text = "`#{smell.context}` #{smell.message}"
      text += " (was: #{finding.previous_message})" if finding.kind == :worse
      text
    end

    def inline_body(finding)
      label = finding.kind == :worse ? 'got worse' : 'new'
      "#{inline_marker(finding.smell)}\n" \
        "**RubyCritic: #{finding.smell.type}** (#{label})\n\n" \
        "#{describe(finding)}\n"
    end

    def location(finding)
      loc = finding.smell.locations.first
      return '-' unless loc

      "`#{loc[:path]}:#{loc[:line]}`"
    end

    def cell(text)
      text.to_s.gsub('|', '\\|').tr("\n", ' ')
    end

    def format_diff(value)
      value.positive? ? "+#{value}" : value.to_s
    end

    # all_count: every finding. listed: findings shown in the table (the ones
    # not already posted inline). note: optional extra line.
    def summary(base_score:, head_score:, findings:, listed:, run_url: nil, note: nil)
      diff = (head_score - base_score).round(2)
      out = +"#{SUMMARY_MARKER}\n## RubyCritic report\n\n"
      out << "| Base | Head | Change |\n|---|---|---|\n"
      out << "| #{base_score.round(2)} | #{head_score.round(2)} | #{format_diff(diff)} |\n\n"
      out << if findings.empty?
               "No new smells introduced by this PR.\n"
             else
               "**#{findings.size}** new or worsened smell#{'s' unless findings.size == 1} in this PR.\n"
             end
      out << "\n#{note}\n" if note
      unless listed.empty?
        out << "\n| Location | Type | Finding |\n|---|---|---|\n"
        listed.each do |f|
          out << "| #{location(f)} | #{f.smell.type} | #{cell(describe(f))} |\n"
        end
      end
      out << "\n[Workflow run](#{run_url})\n" if run_url
      out
    end
  end
end

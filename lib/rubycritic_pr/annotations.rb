# frozen_string_literal: true

module RubycriticPr
  # Workflow-command annotations, used when the token cannot write to the PR.
  module Annotations
    # GitHub shows at most 10 warnings per step.
    DEFAULT_CAP = 10

    module_function

    def escape_data(text)
      text.to_s.gsub('%', '%25').gsub("\r", '%0D').gsub("\n", '%0A')
    end

    def escape_property(text)
      escape_data(text).gsub(':', '%3A').gsub(',', '%2C')
    end

    def format(finding)
      smell = finding.smell
      loc = smell.locations.first
      props = []
      props << "file=#{escape_property(loc[:path])}" << "line=#{loc[:line]}" if loc
      props << "title=#{escape_property(smell.type)}"
      "::warning #{props.join(',')}::#{escape_data(Markdown.describe(finding).delete('`'))}"
    end

    # Returns [lines_to_print, number_omitted].
    def render(findings, cap: DEFAULT_CAP)
      [findings.first(cap).map { |f| format(f) }, [findings.size - cap, 0].max]
    end
  end
end

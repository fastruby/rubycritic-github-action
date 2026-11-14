# frozen_string_literal: true

require 'json'

module RubycriticPr
  # Reads both reports, works out the new smells and reports them on the PR.
  class Runner
    def initialize(env:, client:, out: $stdout)
      @env = env
      @client = client
      @out = out
    end

    def call
      base = Report.load(Report.find(root, @env.fetch('RC_BASE_BRANCH')))
      head = Report.load(Report.find(root, @env.fetch('RC_HEAD_BRANCH')))
      findings = SmellDiff.call(base.smells, head.smells)

      post(base, head, findings)
      write_outputs(base, head, findings)
      fail_reason(findings)
    end

    def fail_reason(findings)
      reasons = []
      reasons << 'score dropped by more than the threshold' if threshold_exceeded?
      reasons << "#{findings.size} new smell(s) found" if truthy?('RC_FAIL_ON_NEW_SMELLS') && findings.any?
      reason = reasons.join('; ')
      set_output('fail-reason', reason)
      reason
    end

    private

    def post(base, head, findings)
      pr = pull_request_number
      return write_summary_only(base, head, findings, 'Not running on a pull request, nothing was posted.') unless pr

      files = fetch_commentable(pr)
      return fallback(base, head, findings, 'No permission to read this PR.') if files.nil?

      inline, listed = split(findings, files)
      if inline_enabled?
        listed += post_inline(pr, skip_already_posted(pr, inline))
      else
        listed += inline.map(&:first)
      end

      body = build_summary(base, head, findings, listed)
      upsert_summary(pr, body)
      @out.puts body
      append_step_summary(body)
    rescue GithubClient::ApiError => e
      raise unless e.status == 403

      fallback(base, head, findings, 'The token cannot write to this PR (likely a fork PR).')
    end

    # Posts one review with all comments. Returns findings that could not be
    # posted inline so they can go in the summary instead.
    def post_inline(pr, inline)
      return [] if inline.empty?

      comments = inline.map do |f, loc|
        { path: loc[:path], line: loc[:line], side: 'RIGHT', body: Markdown.inline_body(f) }
      end
      @client.create_review(pr, commit_id: head_sha, comments: comments)
      []
    rescue GithubClient::ApiError => e
      raise unless e.status == 422

      inline.map(&:first)
    end

    def root
      @env.fetch('RC_REPORT_ROOT')
    end

    def pull_request_number
      event = @env['GITHUB_EVENT_PATH']
      return nil unless event && File.file?(event)

      JSON.parse(File.read(event)).dig('pull_request', 'number')
    end

    def head_sha
      JSON.parse(File.read(@env['GITHUB_EVENT_PATH'])).dig('pull_request', 'head', 'sha')
    end

    def inline_enabled?
      @env.fetch('RC_INLINE_COMMENTS', 'true') != 'false'
    end

    def truthy?(name)
      @env[name] == 'true'
    end

    def threshold_exceeded?
      !@env['RC_THRESHOLD'].to_s.empty? && @env['RC_EXIT_CODE'].to_i != 0
    end

    def fetch_commentable(pr)
      DiffParser.commentable(@client.pull_files(pr))
    rescue GithubClient::ApiError => e
      raise unless [403, 404].include?(e.status)

      nil
    end

    # First location of each finding that sits on a line in the diff goes
    # inline. Everything else is left for the summary.
    def split(findings, files)
      inline = []
      rest = []
      findings.each do |f|
        loc = f.smell.locations.find { |l| files[l[:path]]&.include?(l[:line]) }
        if loc
          inline << [f, loc]
        else
          rest << f
        end
      end
      [inline, rest]
    end

    def skip_already_posted(pr, inline)
      seen = @client.review_comments(pr).map { |c| [c['path'], Markdown.marker_digest(c['body'])] }.to_set
      inline.reject { |f, loc| seen.include?([loc[:path], Markdown.key_digest(f.smell)]) }
    end

    def build_summary(base, head, findings, listed)
      Markdown.summary(
        base_score: base.score, head_score: head.score, findings: findings, listed: listed,
        run_url: run_url, note: threshold_exceeded? ? "Score dropped by more than the threshold (#{@env['RC_THRESHOLD']})." : nil
      )
    end

    def upsert_summary(pr, body)
      existing = @client.issue_comments(pr).find { |c| c['body'].to_s.include?(Markdown::SUMMARY_MARKER) }
      if existing
        @client.update_issue_comment(existing['id'], body)
      else
        @client.create_issue_comment(pr, body)
      end
    end

    def run_url
      return nil unless @env['GITHUB_RUN_ID']

      "#{@env.fetch('GITHUB_SERVER_URL', 'https://github.com')}/#{@env['GITHUB_REPOSITORY']}/actions/runs/#{@env['GITHUB_RUN_ID']}"
    end

    def fallback(base, head, findings, reason)
      lines, omitted = Annotations.render(findings)
      lines.each { |l| @out.puts l }
      note = "#{reason} Findings are shown as annotations instead of PR comments."
      note += " #{omitted} more finding(s) not annotated (GitHub caps annotations per step)." if omitted.positive?
      body = Markdown.summary(base_score: base.score, head_score: head.score, findings: findings,
                              listed: findings, run_url: run_url, note: note)
      append_step_summary(body)

    end

    def write_summary_only(base, head, findings, note)
      body = Markdown.summary(base_score: base.score, head_score: head.score, findings: findings,
                              listed: findings, run_url: run_url, note: note)
      @out.puts body
      append_step_summary(body)
      false
    end

    def append_step_summary(body)
      path = @env['GITHUB_STEP_SUMMARY']
      File.open(path, 'a') { |f| f.puts(body) } if path
    end

    def write_outputs(base, head, findings)
      set_output('base-score', base.score.round(2))
      set_output('head-score', head.score.round(2))
      set_output('score-diff', (head.score - base.score).round(2))
      set_output('new-smells-count', findings.size)
    end

    def set_output(name, value)
      path = @env['GITHUB_OUTPUT']
      File.open(path, 'a') { |f| f.puts("#{name}=#{value}") } if path
    end
  end
end

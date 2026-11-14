# frozen_string_literal: true

require 'test_helper'

class FakeClient
  attr_reader :reviews, :created, :updated
  attr_accessor :files, :existing_review_comments, :existing_issue_comments, :write_error

  def initialize(files:)
    @files = files
    @existing_review_comments = []
    @existing_issue_comments = []
    @reviews = []
    @created = []
    @updated = []
  end

  def pull_files(_n) = @files
  def review_comments(_n) = @existing_review_comments
  def issue_comments(_n) = @existing_issue_comments

  def create_review(_n, commit_id:, comments:)
    raise @write_error if @write_error

    @reviews << { commit_id: commit_id, comments: comments }
  end

  def create_issue_comment(_n, body)
    raise @write_error if @write_error

    @created << body
  end

  def update_issue_comment(id, body)
    @updated << [id, body]
  end
end

class RunnerTest < Minitest::Test
  include Builders

  def setup
    @dir = Dir.mktmpdir
    @out = StringIO.new
    event = File.join(@dir, 'event.json')
    File.write(event, JSON.generate('pull_request' => { 'number' => 7, 'head' => { 'sha' => 'abc' } }))
    @env = {
      'RC_BASE_BRANCH' => 'rubycritic-base', 'RC_HEAD_BRANCH' => 'feature/add-smells',
      'RC_REPORT_ROOT' => @dir, 'GITHUB_EVENT_PATH' => event,
      'GITHUB_OUTPUT' => File.join(@dir, 'output'), 'GITHUB_STEP_SUMMARY' => File.join(@dir, 'summary')
    }
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def write_reports(base:, head:)
    # head branch contains a slash, so the report is nested
    { 'rubycritic-base' => base, 'feature/add-smells' => head }.each do |branch, data|
      path = File.join(@dir, 'compare', branch, 'report.json')
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.generate(data))
    end
  end

  def files(lines = '@@ -1,0 +1,5 @@' + "\n+a\n+b\n+c\n+d\n+e\n")
    [{ 'filename' => 'lib/foo.rb', 'status' => 'modified', 'patch' => lines }]
  end

  def run_runner(client)
    RubycriticPr::Runner.new(env: @env, client: client, out: @out).call
  end

  def outputs
    File.read(@env['GITHUB_OUTPUT']).lines.map { |l| l.chomp.split('=', 2) }.to_h
  end

  def test_clean_refactor_posts_summary_only
    write_reports(base: report_hash(smells: [smell]), head: report_hash(smells: [smell]))
    client = FakeClient.new(files: files)
    run_runner(client)
    assert_empty client.reviews
    assert_includes client.created.first, 'No new smells'
    assert_equal '0', outputs['new-smells-count']
  end

  def test_new_smell_on_diff_line_is_inline
    write_reports(base: report_hash(score: 90), head: report_hash(smells: [smell], score: 85.5))
    client = FakeClient.new(files: files)
    run_runner(client)
    comment = client.reviews.first[:comments].first
    assert_equal ['lib/foo.rb', 3, 'RIGHT'], comment.values_at(:path, :line, :side)
    assert_equal 'abc', client.reviews.first[:commit_id]
    assert_equal '-4.5', outputs['score-diff']
    assert_equal '1', outputs['new-smells-count']
    refute_includes client.created.first, '| `lib/foo.rb:3`'
  end

  def test_smell_outside_diff_goes_to_summary
    write_reports(base: report_hash, head: report_hash(smells: [smell(locations: [{ 'path' => 'lib/foo.rb', 'line' => 50 }])]))
    client = FakeClient.new(files: files)
    run_runner(client)
    assert_empty client.reviews
    assert_includes client.created.first, '`lib/foo.rb:50`'
  end

  def test_second_run_does_not_duplicate_inline_or_summary
    write_reports(base: report_hash, head: report_hash(smells: [smell]))
    client = FakeClient.new(files: files)
    run_runner(client)
    posted = client.reviews.first[:comments].first
    client.existing_review_comments = [{ 'path' => posted[:path], 'body' => posted[:body] }]
    client.existing_issue_comments = [{ 'id' => 99, 'body' => client.created.first }]
    run_runner(client)
    assert_equal 1, client.reviews.size
    assert_equal 1, client.created.size
    assert_equal 99, client.updated.first.first
  end

  def test_inline_disabled_lists_everything_in_summary
    @env['RC_INLINE_COMMENTS'] = 'false'
    write_reports(base: report_hash, head: report_hash(smells: [smell]))
    client = FakeClient.new(files: files)
    run_runner(client)
    assert_empty client.reviews
    assert_includes client.created.first, '`lib/foo.rb:3`'
  end

  def test_threshold_failure_sets_fail_reason
    @env.merge!('RC_THRESHOLD' => '0', 'RC_EXIT_CODE' => '1')
    write_reports(base: report_hash(score: 90), head: report_hash(score: 80))
    run_runner(FakeClient.new(files: files))
    assert_match(/threshold/, outputs['fail-reason'])
  end

  def test_fail_on_new_smells
    @env['RC_FAIL_ON_NEW_SMELLS'] = 'true'
    write_reports(base: report_hash, head: report_hash(smells: [smell]))
    run_runner(FakeClient.new(files: files))
    assert_match(/1 new smell/, outputs['fail-reason'])
  end

  def test_no_fail_reason_when_clean
    write_reports(base: report_hash, head: report_hash)
    run_runner(FakeClient.new(files: files))
    assert_equal '', outputs['fail-reason']
  end

  def test_read_only_token_falls_back_to_annotations
    write_reports(base: report_hash, head: report_hash(smells: [smell]))
    client = FakeClient.new(files: files)
    client.write_error = RubycriticPr::GithubClient::ApiError.new(403, 'Resource not accessible by integration')
    run_runner(client)
    assert_includes @out.string, '::warning file=lib/foo.rb,line=3,title=TooManyStatements::'
    assert_includes File.read(@env['GITHUB_STEP_SUMMARY']), 'annotations instead of PR comments'
  end

  def test_rejected_inline_line_falls_back_to_summary
    write_reports(base: report_hash, head: report_hash(smells: [smell]))
    client = FakeClient.new(files: files)
    client.define_singleton_method(:create_review) { |*_a, **_k| raise RubycriticPr::GithubClient::ApiError.new(422, 'bad line') }
    run_runner(client)
    assert_includes client.created.first, '`lib/foo.rb:3`'
  end

  def test_missing_report_raises
    assert_raises(RubycriticPr::Report::MissingReport) { run_runner(FakeClient.new(files: [])) }
  end
end

# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module RubycriticPr
  # Minimal GitHub REST client on net/http.
  class GithubClient
    class ApiError < StandardError
      attr_reader :status

      def initialize(status, message)
        @status = status
        super("GitHub API #{status}: #{message}")
      end
    end

    def initialize(token:, repo:, api_url: 'https://api.github.com')
      @token = token
      @repo = repo
      @api_url = api_url
    end

    def pull_files(number)
      paginate("/repos/#{@repo}/pulls/#{number}/files")
    end

    def review_comments(number)
      paginate("/repos/#{@repo}/pulls/#{number}/comments")
    end

    def issue_comments(number)
      paginate("/repos/#{@repo}/issues/#{number}/comments")
    end

    def create_review(number, commit_id:, comments:)
      request(:post, "/repos/#{@repo}/pulls/#{number}/reviews",
              { commit_id: commit_id, event: 'COMMENT', comments: comments })
    end

    def create_issue_comment(number, body)
      request(:post, "/repos/#{@repo}/issues/#{number}/comments", { body: body })
    end

    def update_issue_comment(id, body)
      request(:patch, "/repos/#{@repo}/issues/comments/#{id}", { body: body })
    end

    private

    def paginate(path)
      results = []
      page = 1
      loop do
        batch = request(:get, "#{path}?per_page=100&page=#{page}")
        results.concat(batch)
        break if batch.size < 100

        page += 1
      end
      results
    end

    def request(verb, path, body = nil)
      uri = URI("#{@api_url}#{path}")
      klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch }.fetch(verb)
      req = klass.new(uri)
      req['Authorization'] = "Bearer #{@token}"
      req['Accept'] = 'application/vnd.github+json'
      req['X-GitHub-Api-Version'] = '2022-11-28'
      req['User-Agent'] = 'rubycritic-github-action'
      if body
        req['Content-Type'] = 'application/json'
        req.body = JSON.generate(body)
      end
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') { |http| http.request(req) }
      raise ApiError.new(res.code.to_i, res.body.to_s[0, 300]) unless res.is_a?(Net::HTTPSuccess)

      res.body.to_s.empty? ? nil : JSON.parse(res.body)
    end
  end
end

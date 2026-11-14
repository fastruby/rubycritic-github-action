# RubyCritic PR Comments

A GitHub Action that runs [RubyCritic](https://github.com/whitesmith/rubycritic) in compare mode on a pull request and comments on the smells the PR **introduced**:

- inline review comments on lines that are part of the PR diff
- one summary comment, edited in place on every push, with the score change and any findings that can't go inline
- annotations and the job summary instead, when the token can't write (PRs from forks)

## Usage

```yaml
name: RubyCritic
on: pull_request

permissions:
  contents: read
  pull-requests: write

jobs:
  rubycritic:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0 # required, RubyCritic compares git branches
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.4'
      - uses: fastruby/rubycritic-github-action@v0.1.0
        with:
          paths: app lib
```

Use the `pull_request` trigger. Do not use `pull_request_target`, since this action runs code from the PR.

## Inputs

| Input | Default | Purpose |
|---|---|---|
| `base-branch` | PR base ref | Branch to compare against |
| `paths` | `.` | Paths to analyze |
| `threshold` | none | Fail if the score drops by more than this |
| `rubycritic-version` | latest | Gem version to install |
| `use-bundle` | `false` | Run `bundle exec rubycritic` (RubyCritic must be in your Gemfile and installed) |
| `inline-comments` | `true` | Post inline review comments |
| `fail-on-new-smells` | `false` | Fail the job if there are any new findings |
| `upload-artifact` | `true` | Upload the HTML and JSON reports as an artifact |
| `github-token` | `${{ github.token }}` | Token used to post |

## Outputs

| Output | Meaning |
|---|---|
| `base-score` | Score on the base branch |
| `head-score` | Score on the PR head |
| `score-diff` | Head minus base |
| `new-smells-count` | Number of new or worsened smells |

## How it decides what is new

RubyCritic's own smell identity is `[context, message, score, type]`, without locations, so moved code isn't flagged. The action uses the same key and treats smells as a multiset: if a key shows up more often in the head report than in the base report, the extra copies are new. If a smell with the same type and context exists in base but its message or score changed (for example "12 statements" to "14"), it's labeled "got worse".

The base is the merge base of the PR head and the base branch, so changes that landed on the base branch after you branched don't show up as yours.

Findings that point at lines outside the PR diff go in the summary comment. Smells that already have an inline comment from an earlier push (same file and smell) aren't posted again.

## Failing the job

The comments are always posted first. The job then fails if the score dropped by more than `threshold`, or if `fail-on-new-smells` is on and there are findings.

## Fork PRs

On `pull_request`, PRs from forks get a read-only token. When a write returns 403 the action skips the review and comment, emits `::warning` annotations (GitHub shows about 10 per step, the summary says how many were left out), and writes the full summary to the job summary.

## Development

```
bundle install
bundle exec rake test
```

See [TESTING.md](TESTING.md) for the end-to-end scenarios.

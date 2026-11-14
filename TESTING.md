# End-to-end testing

Run against [fastruby/rubycritic-action-sandbox](https://github.com/fastruby/rubycritic-action-sandbox), using this action from the `dev` branch. Results were checked through the API (`gh api`), not just in the UI.

| Scenario | PR | Run | Expected | Actual |
|---|---|---|---|---|
| A: clean refactor (method moved) | [#1](https://github.com/fastruby/rubycritic-action-sandbox/pull/1) | [run](https://github.com/fastruby/rubycritic-action-sandbox/actions/runs/43546131041) | No inline comments, summary says no new smells | Pass. 0 review comments, 1 summary, score 98.87 to 98.87 |
| B: new smells | [#2](https://github.com/fastruby/rubycritic-action-sandbox/pull/2) | [run](https://github.com/fastruby/rubycritic-action-sandbox/actions/runs/43546133881) | Inline comments on new lines, score diff, one summary | Pass. 10 inline comments, score 98.87 to 95.55 (-3.32) |
| B: second push | [#2](https://github.com/fastruby/rubycritic-action-sandbox/pull/2) | [run](https://github.com/fastruby/rubycritic-action-sandbox/actions/runs/43546281589) | One summary (updated), no duplicate inline comments | Pass. Still 1 summary (updated to -3.48), 13 inline comments with 13 unique markers (only the 3 new smells were added) |
| C: smell outside the diff | [#3](https://github.com/fastruby/rubycritic-action-sandbox/pull/3) | [run](https://github.com/fastruby/rubycritic-action-sandbox/actions/runs/43546140217) | Finding in the summary, not inline | Pass. `Report#build` "got worse" (8 to 10 statements) reported at the unchanged `def` line in the summary table, 0 review comments |
| D: threshold 0 | [#4](https://github.com/fastruby/rubycritic-action-sandbox/pull/4) | [run](https://github.com/fastruby/rubycritic-action-sandbox/actions/runs/43546144054) | Job fails after comments are posted | Pass. Job failed, 10 inline comments and the summary were present |
| E: read-only token | [#5](https://github.com/fastruby/rubycritic-action-sandbox/pull/5) | [run](https://github.com/fastruby/rubycritic-action-sandbox/actions/runs/43546150671) | Annotations and job summary, no write errors | Pass. Job succeeded, 10 warning annotations (the cap), no PR comments |
| Slash in head branch | [#2](https://github.com/fastruby/rubycritic-action-sandbox/pull/2) | same as B | Reports found | Pass. PR branches are `feature/add-smells`, `refactor/move-method`, etc. The action compares fixed local branches, so nested report paths never occur in CI. A local run with a nested head branch (`compare/feature/add-smells/report.json`) was parsed correctly, and `Report.find` has a unit test for it |

## Notes

- A fork PR was simulated with `pull-requests: read`, as in the brief. A real fork PR was not opened.
- Checked locally against RubyCritic 5.0.0: `-b`, repeated `-f`, `-p` and `-t` behave as the brief describes, the working tree stays clean, and a threshold failure still writes the reports.

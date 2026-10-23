# clearvia/check-action

Checks a repository against the [Clearvia deployment standard](https://docs.clearvia.app/standard/overview)
and uploads the result to Clearvia as a check run. The workflow authenticates
with its GitHub OIDC token, so you store no Clearvia secret in the repository.

Use it as `clearvia/check-action@v1`.

## Use

1. In the Clearvia console, an owner or admin links the project to this
   repository by its GitHub repository id (`gh api repos/OWNER/NAME --jq .id`).
   A refused upload prints the id too.
2. Add a workflow:

```yaml
name: Clearvia
on:
  push:
    branches: [main]
  pull_request:

jobs:
  check:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write # the OIDC token Clearvia verifies
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with:
          node-version: 22
      - uses: clearvia/check-action@v1
        with:
          organization: acme # your organization's slug
          # project: web     # only when the repository is linked to several projects
          # region: china
          # level: c1
```

| Input              | Default                    | Meaning                                                                     |
| ------------------ | -------------------------- | --------------------------------------------------------------------------- |
| `organization`     |                            | The organization's slug. Required to upload without an API key.             |
| `project`          |                            | The project's slug, when the repository is linked to more than one project. |
| `path`             | `.`                        | The directory to check.                                                     |
| `region`           | every rule                 | `china` or `international`.                                                 |
| `level`            | `c0`                       | The level the project must reach.                                           |
| `fail-below-level` | `true`                     | `false` reports without failing the step when the project is below `level`. |
| `upload`           | `true`                     | `false` only prints the report.                                             |
| `api-url`          | `https://api.clearvia.app` | The Clearvia API. The OIDC token's audience is its origin.                  |
| `cli-version`      | `latest`                   | The CLI release, such as `0.59.0`.                                          |
| `cli-repository`   | `clearvia/check-action`    | Where the CLI releases live.                                                |
| `cli-tarball`      |                            | A local `clearvia-cli.tgz` to install instead of a download.                |

On `pull_request` events the run records the pull request's head commit and branch, not GitHub's merge commit, so the Clearvia check (with the GitHub App) shows on the pull request. `CLEARVIA_COMMIT_SHA` and `CLEARVIA_REF` in the job's environment override both.

Output `run-url` is the uploaded run in the console. The text report goes to
the log and the job summary.

The step exits non-zero when the project is below `level` (unless
`fail-below-level: false`) and when the check or the upload fails.

## How it authenticates

The CLI asks GitHub for an OIDC token with the API's origin as audience, right
after the check, and sends it to `POST /api/check-runs/github`. The API
verifies the token's signature against GitHub's published keys, its issuer,
audience and expiry, then accepts the run only for a project of the named
organization that is linked to the token's `repository_id`. Renaming or
transferring the repository keeps its id; unlinking the project stops uploads.

Uploads from pull requests of forks get no OIDC token from GitHub and fail
with a clear message; run the check without `upload` there. Do not grant
`id-token: write` to `pull_request_target` workflows that check out untrusted
code.

With `CLEARVIA_API_KEY` in the job's environment the CLI uses the key instead,
and `project` is required.

## Install

The action downloads `clearvia-cli.tgz` from a `platform-v*` release of
`cli-repository`, checks it against `clearvia-cli.tgz.sha256`, and installs it
with npm, which fetches the exact `typescript` and `yaml` versions the CLI was
tested with. It needs Node.js 20 or later on the runner, `bash`, `curl` and
`npm`; GitHub's Linux and macOS runners have them.

## Releases

Each Clearvia platform release publishes the CLI here as a `platform-vX.Y.Z`
release carrying `clearvia-cli.tgz` and `clearvia-cli.tgz.sha256`.
`cli-version: latest` installs the newest one. The action itself is versioned
by the `v1` tag.

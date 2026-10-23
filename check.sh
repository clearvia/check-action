#!/usr/bin/env bash
# Runs clearvia check (and --upload) with the action's inputs, writes the text
# report to the log and the job summary, and sets the run-url output.
#
# Without CLEARVIA_API_KEY in the job's environment, the CLI uploads with the
# workflow's OIDC token, which needs `permissions: id-token: write`.
set -uo pipefail

directory="${RUNNER_TEMP:?}/clearvia-cli"
clearvia="${directory}/install/node_modules/.bin/clearvia"

arguments=(check "${CHECK_PATH:-.}" --level "${CHECK_LEVEL:-c0}")
[[ -n "${CHECK_REGION:-}" ]] && arguments+=(--region "${CHECK_REGION}")
[[ "${CHECK_UPLOAD:-true}" == "true" ]] && arguments+=(--upload)

[[ -n "${INPUT_API_URL:-}" ]] && export CLEARVIA_API_URL="${INPUT_API_URL}"
[[ -n "${INPUT_ORGANIZATION:-}" ]] && export CLEARVIA_ORGANIZATION="${INPUT_ORGANIZATION}"
[[ -n "${INPUT_PROJECT:-}" ]] && export CLEARVIA_PROJECT="${INPUT_PROJECT}"

# On a pull request GITHUB_SHA is GitHub's merge commit and GITHUB_REF_NAME is
# "N/merge"; the run describes the pull request's head commit and branch, where
# its check shows. Values the job sets itself win.
[[ -n "${PR_HEAD_SHA:-}" && -z "${CLEARVIA_COMMIT_SHA:-}" ]] && export CLEARVIA_COMMIT_SHA="${PR_HEAD_SHA}"
[[ -n "${PR_HEAD_REF:-}" && -z "${CLEARVIA_REF:-}" ]] && export CLEARVIA_REF="${PR_HEAD_REF}"

"${clearvia}" "${arguments[@]}" >"${directory}/report.txt" 2>"${directory}/stderr.txt"
status=$?
cat "${directory}/report.txt"
cat "${directory}/stderr.txt" >&2

run_url="$(grep -Eo 'https?://[^ ]+/runs/[^ ]+' "${directory}/stderr.txt" | tail -n 1 || true)"
echo "run-url=${run_url}" >>"${GITHUB_OUTPUT:-/dev/null}"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
	{
		echo "### Clearvia check"
		echo
		[[ -n "${run_url}" ]] && echo "Uploaded: ${run_url}" && echo
		echo '```text'
		cat "${directory}/report.txt"
		echo '```'
	} >>"${GITHUB_STEP_SUMMARY}"
fi

# 1 is "below the target level"; 2 is a usage, runtime or upload error.
if [[ ${status} -eq 1 && "${CHECK_FAIL_BELOW_LEVEL:-true}" != "true" ]]; then
	echo "::warning title=clearvia::Below ${CHECK_LEVEL:-c0}; fail-below-level is false, so the step passes."
	exit 0
fi
exit "${status}"

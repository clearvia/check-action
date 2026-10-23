#!/usr/bin/env bash
# Installs the clearvia CLI release asset into $RUNNER_TEMP/clearvia-cli.
#
# The asset is clearvia-cli.tgz from a platform-v* GitHub release, checked
# against the clearvia-cli.tgz.sha256 beside it, then installed with npm, which
# fetches the exact typescript and yaml versions its manifest pins.
set -euo pipefail

fail() {
	echo "::error title=clearvia::$1"
	exit 1
}

node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if ((node_major < 20)); then
	fail "clearvia needs Node.js 20 or later on the runner. Add actions/setup-node before this step."
fi

directory="${RUNNER_TEMP:?}/clearvia-cli"
rm -rf "${directory}"
mkdir -p "${directory}/download" "${directory}/install"

if [[ -n "${CLI_TARBALL:-}" ]]; then
	[[ -f "${CLI_TARBALL}" ]] || fail "cli-tarball ${CLI_TARBALL} does not exist."
	tarball="$(cd "$(dirname "${CLI_TARBALL}")" && pwd)/$(basename "${CLI_TARBALL}")"
	echo "Installing clearvia from ${CLI_TARBALL}"
else
	[[ "${CLI_REPOSITORY:-}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] ||
		fail "cli-repository must be owner/name; got '${CLI_REPOSITORY:-}'."

	case "${CLI_VERSION:-latest}" in
	latest) base="https://github.com/${CLI_REPOSITORY}/releases/latest/download" ;;
	platform-v[0-9]*.[0-9]*.[0-9]*) base="https://github.com/${CLI_REPOSITORY}/releases/download/${CLI_VERSION}" ;;
	v[0-9]*.[0-9]*.[0-9]* | [0-9]*.[0-9]*.[0-9]*)
		base="https://github.com/${CLI_REPOSITORY}/releases/download/platform-v${CLI_VERSION#v}"
		;;
	*) fail "cli-version must be latest or a release such as 0.59.0; got '${CLI_VERSION}'." ;;
	esac

	echo "Downloading clearvia from ${base}"
	for asset in clearvia-cli.tgz clearvia-cli.tgz.sha256; do
		curl --fail --silent --show-error --location --retry 3 --retry-delay 2 \
			--output "${directory}/download/${asset}" "${base}/${asset}" ||
			fail "Could not download ${base}/${asset}. The repository's releases must be public, and the release must carry the CLI."
	done

	expected="$(awk '{ print $1 }' "${directory}/download/clearvia-cli.tgz.sha256")"
	if command -v sha256sum >/dev/null; then
		actual="$(sha256sum "${directory}/download/clearvia-cli.tgz" | awk '{ print $1 }')"
	else
		actual="$(shasum -a 256 "${directory}/download/clearvia-cli.tgz" | awk '{ print $1 }')"
	fi
	[[ -n "${expected}" && "${expected}" == "${actual}" ]] ||
		fail "clearvia-cli.tgz does not match its checksum (expected ${expected}, got ${actual})."
	tarball="${directory}/download/clearvia-cli.tgz"
fi

npm install --prefix "${directory}/install" --no-audit --no-fund --omit=dev --loglevel=error "${tarball}"
"${directory}/install/node_modules/.bin/clearvia" --help >/dev/null
echo "Installed clearvia $(node -p "require('${directory}/install/node_modules/@clearvia/cli/package.json').version")"

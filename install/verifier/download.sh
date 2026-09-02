#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright 2026 The SLSA Authors
# SPDX-License-Identifier: Apache-2.0
#
# Downloads a slsa-verifier release for the runner's platform, along
# with the provenance published with it, and emits what the AMPEL
# verification step needs to check the binary before it is installed.
# Inputs arrive through the environment:
#
#   VERSION   release tag to download (default: DEFAULT_VERSION below)
#   REPO      GitHub repository publishing the releases
#   VERIFY    "false" skips downloading the provenance
#
# Outputs: binary, attestations (empty when VERIFY=false), version,
# builder-id (the release workflow the provenance must name) and
# signer (a sigstore regexp spec pinning the same workflow at the
# requested tag).
set -euo pipefail

DEFAULT_VERSION="v0.1.0-alpha.1"
RELEASE_WORKFLOW=".github/workflows/release.yaml"
ISSUER="https://token.actions.githubusercontent.com"

VERSION="${VERSION:-$DEFAULT_VERSION}"
REPO="${REPO:-slsa-framework/verifier}"
VERIFY="${VERIFY:-true}"

log() { echo "$*" >&2; }
fail() { echo "::error::$*" >&2; exit 1; }

case "$VERSION" in
  v[0-9]*) ;;
  *) fail "version must be a release tag (vX.Y.Z), got: $VERSION" ;;
esac
case "$REPO" in
  */*) ;;
  *) fail "repo must be owner/name, got: $REPO" ;;
esac

os="${RUNNER_OS:-$(uname -s)}"
arch="${RUNNER_ARCH:-$(uname -m)}"
case "$os" in
  Linux|linux)    os=linux ;;
  macOS|Darwin)   os=darwin ;;
  Windows|MINGW*|MSYS*|CYGWIN*) os=windows ;;
  *) fail "unsupported OS: $os" ;;
esac
case "$arch" in
  X64|x86_64|amd64)  arch=amd64 ;;
  ARM64|aarch64|arm64) arch=arm64 ;;
  *) fail "unsupported architecture: $arch" ;;
esac
ext=""
[ "$os" = windows ] && ext=".exe"

download() { # url dest
  curl -sSfL --retry 3 --retry-all-errors --retry-delay 2 -o "$2" "$1" \
    || fail "downloading $1"
}

work="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/slsa-verifier-release"
mkdir -p "$work"
release_file="slsa-verifier-${VERSION}-${os}-${arch}${ext}"
binary="${work}/${release_file}"
log "Downloading ${release_file}"
download "https://github.com/${REPO}/releases/download/${VERSION}/${release_file}" "$binary"
chmod 0755 "$binary"

attestations=""
if [ "$VERIFY" = "true" ]; then
  attestations="${work}/attestations.jsonl"
  download "https://github.com/${REPO}/releases/download/${VERSION}/attestations.jsonl" "$attestations"
else
  log "::warning::Skipping provenance verification of ${release_file}"
fi

# Emit paths in a spelling every consumer accepts; see install.sh.
if command -v cygpath >/dev/null 2>&1; then
  binary="$(cygpath -m "$binary")"
  [ -n "$attestations" ] && attestations="$(cygpath -m "$attestations")"
fi

# The provenance must name the repository's release workflow as the
# builder and be signed by the same workflow running at the requested
# tag. Regexp metacharacters in the repo and tag are escaped; the spec
# is anchored so a name sharing a prefix does not match.
workflow="https://github.com/${REPO}/${RELEASE_WORKFLOW}"
escaped_workflow="$(printf '%s' "$workflow" | sed 's/[.+]/\\&/g')"
escaped_version="$(printf '%s' "$VERSION" | sed 's/[.+]/\\&/g')"
escaped_issuer="$(printf '%s' "$ISSUER" | sed 's/[.+]/\\&/g')"
signer="sigstore(regexp)::${escaped_issuer}::^${escaped_workflow}@refs/tags/${escaped_version}\$"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "binary=${binary}"
    echo "attestations=${attestations}"
    echo "version=${VERSION}"
    echo "builder-id=${workflow}"
    echo "signer=${signer}"
  } >> "$GITHUB_OUTPUT"
fi

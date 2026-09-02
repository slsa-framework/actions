#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright 2026 The SLSA Authors
# SPDX-License-Identifier: Apache-2.0
#
# Installs an already-verified slsa-verifier binary under
# INSTALL_DIR/bin. Inputs arrive through the environment:
#
#   BINARY        path of the binary to install (download.sh's output)
#   VERSION       release the binary came from, for the outputs
#   INSTALL_DIR   directory to install into (default: $HOME/.slsa)
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/.slsa}"

fail() { echo "::error::$*" >&2; exit 1; }

[ -n "${BINARY:-}" ] || fail "BINARY is required"
[ -f "$BINARY" ] || fail "binary not found: ${BINARY}"
case "$INSTALL_DIR" in
  ''|*[!A-Za-z0-9._/\\:~\$-]*) fail "install-dir must contain only [A-Za-z0-9._/:~\$-], got: $INSTALL_DIR" ;;
esac
# The value may arrive unexpanded from an action input.
case "$INSTALL_DIR" in
  '$HOME'|'$HOME'/*) INSTALL_DIR="${HOME}${INSTALL_DIR#\$HOME}" ;;
  '~'|'~'/*)         INSTALL_DIR="${HOME}${INSTALL_DIR#\~}" ;;
esac

ext=""
case "$BINARY" in *.exe) ext=".exe" ;; esac
mkdir -p "${INSTALL_DIR}/bin"
installed="${INSTALL_DIR}/bin/slsa-verifier${ext}"
cp "$BINARY" "$installed"
chmod 0755 "$installed"

# On Windows this script runs under Git Bash, whose /c/... paths mean
# nothing to the rest of the runner. cygpath -m yields C:/... — a
# spelling every consumer understands: Windows path resolution and PATH
# entries accept forward slashes, and Git Bash converts them back.
bin_dir="${INSTALL_DIR}/bin"
if command -v cygpath >/dev/null 2>&1; then
  installed="$(cygpath -m "$installed")"
  bin_dir="$(cygpath -m "$bin_dir")"
fi
echo "Installed slsa-verifier ${VERSION:-} at ${installed}" >&2

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "path=${installed}"
    echo "bin-dir=${bin_dir}"
    echo "version=${VERSION:-}"
  } >> "$GITHUB_OUTPUT"
fi

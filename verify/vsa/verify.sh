#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright 2026 The SLSA Authors
# SPDX-License-Identifier: Apache-2.0
#
# Verifies a SLSA Verification Summary Attestation with slsa-verifier
# vsa. The attestation is a file (INPUT_ATTESTATION) or the git note of
# a commit of the checked-out repository (INPUT_COMMIT). Inputs arrive
# through the environment, prefixed INPUT_, and map onto the command's
# flags; see action.yml.
set -euo pipefail
# shellcheck source=../lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

attestation="$(attestation_input)"

VERIFIER="${VERIFIER:?path of the verified slsa-verifier binary}"

ARGS=(vsa "$attestation")
while IFS= read -r artifact; do
  ARGS+=("$artifact")
done < <(lines "${INPUT_ARTIFACTS:-}")
add_each --subject "${INPUT_SUBJECTS:-}"
if [ -n "${INPUT_COMMIT:-}" ]; then
  ARGS+=(--subject "gitCommit:${INPUT_COMMIT}")
fi

add_each --verifier "${INPUT_VERIFIER:-}"
add_bool --allow-unbound-verifier "${INPUT_ALLOW_UNBOUND_VERIFIER:-}"
add_each --signer "${INPUT_SIGNER:-}"
add_bool --require-signatures "${INPUT_REQUIRE_SIGNATURES:-}"
add_each --key "${INPUT_KEY:-}"
add_each --level "${INPUT_LEVEL:-}"
add_flag --resource "${INPUT_RESOURCE:-}"
add_flag --policy "${INPUT_POLICY:-}"
add_each --dependency "${INPUT_DEPENDENCY:-}"
add_raw_args "${INPUT_ARGS:-}"

run_verification "$VERIFIER" "SLSA VSA verification"

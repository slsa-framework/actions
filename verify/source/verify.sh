#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright 2026 The SLSA Authors
# SPDX-License-Identifier: Apache-2.0
#
# Verifies a SLSA source attestation with slsa-verifier source. The
# attestation is a file (INPUT_ATTESTATION) or the git note of a commit
# of the checked-out repository (INPUT_COMMIT). Inputs arrive through
# the environment, prefixed INPUT_, and map onto the command's flags;
# see action.yml.
set -euo pipefail
# shellcheck source=../lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

attestation="$(attestation_input)"
commit="${INPUT_COMMIT:-}"

VERIFIER="${VERIFIER:?path of the verified slsa-verifier binary}"

ARGS=(source "$attestation")
[ -n "$commit" ] && ARGS+=("$commit")
add_flag --subject "${INPUT_SUBJECT:-}"
add_flag --expected-repo "${INPUT_EXPECTED_REPO:-}"
add_flag --expected-branch "${INPUT_EXPECTED_BRANCH:-}"
add_flag --expected-tag "${INPUT_EXPECTED_TAG:-}"
add_bool --official "${INPUT_OFFICIAL:-}"
add_each --signer "${INPUT_SIGNER:-}"
add_bool --require-signatures "${INPUT_REQUIRE_SIGNATURES:-}"
add_each --key "${INPUT_KEY:-}"
add_each --param "${INPUT_PARAMS:-}"
add_flag --level "${INPUT_LEVEL:-}"
add_flag --since "${INPUT_SINCE:-}"
add_flag --spec "${INPUT_SPEC:-}"
add_flag --controls "${INPUT_CONTROLS:-}"
add_bool --verbose "${INPUT_VERBOSE:-}"
add_flag --verifier-id "${INPUT_VERIFIER_ID:-}"
add_raw_args "${INPUT_ARGS:-}"

VSA_PATH="${INPUT_VSA:-}"
run_verification "$VERIFIER" "SLSA source verification"

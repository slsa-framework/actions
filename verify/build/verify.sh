#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright 2026 The SLSA Authors
# SPDX-License-Identifier: Apache-2.0
#
# Verifies a SLSA build attestation with slsa-verifier build. Inputs
# arrive through the environment, prefixed INPUT_, and map onto the
# command's flags; see action.yml.
set -euo pipefail
# shellcheck source=../lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

[ -n "${INPUT_ATTESTATION:-}" ] || fail "attestation is required"
[ -f "${INPUT_ATTESTATION}" ] || fail "attestation not found: ${INPUT_ATTESTATION}"

VERIFIER="${VERIFIER:?path of the verified slsa-verifier binary}"

ARGS=(build "${INPUT_ATTESTATION}")
while IFS= read -r artifact; do
  ARGS+=("$artifact")
done < <(lines "${INPUT_ARTIFACTS:-}")
add_each --subject "${INPUT_SUBJECTS:-}"

add_param expected_source "${INPUT_EXPECTED_SOURCE:-}"
add_param expected_branch "${INPUT_EXPECTED_BRANCH:-}"
add_param expected_tag "${INPUT_EXPECTED_TAG:-}"
add_param expected_versioned_tag "${INPUT_EXPECTED_VERSIONED_TAG:-}"
add_list_param expected_workflow_inputs "${INPUT_EXPECTED_WORKFLOW_INPUTS:-}"
add_list_param trusted_builders "${INPUT_TRUSTED_BUILDERS:-}"
add_each --param "${INPUT_PARAMS:-}"

add_each --signer "${INPUT_SIGNER:-}"
add_bool --require-signatures "${INPUT_REQUIRE_SIGNATURES:-}"
add_each --key "${INPUT_KEY:-}"
add_each --builder "${INPUT_BUILDER:-}"
add_flag --builders "${INPUT_BUILDERS:-}"
add_flag --level "${INPUT_LEVEL:-}"
add_flag --spec "${INPUT_SPEC:-}"
add_flag --controls "${INPUT_CONTROLS:-}"
add_bool --skip-buildtype-checks "${INPUT_SKIP_BUILDTYPE_CHECKS:-}"
add_bool --verbose "${INPUT_VERBOSE:-}"
add_flag --verifier-id "${INPUT_VERIFIER_ID:-}"
add_raw_args "${INPUT_ARGS:-}"

VSA_PATH="${INPUT_VSA:-}"
run_verification "$VERIFIER" "SLSA build verification"

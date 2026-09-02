#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright 2026 The SLSA Authors
# SPDX-License-Identifier: Apache-2.0
#
# Shared by the verify/* actions: installs the verifier, turns action
# inputs into command-line arguments, runs the verification and reports
# it. Sourced, not executed.

VERIFY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fail() { echo "::error::$*" >&2; exit 2; }

# lines prints the non-empty, trimmed lines of a newline-separated input.
lines() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -n "$line" ] && printf '%s\n' "$line"
  done <<< "$1"
}

# note_attestation writes the git note of COMMIT, read from the origin
# of the repository checked out at DIR, to a file and prints its path.
# The commit must be a full lowercase sha.
note_attestation() {
  local commit="$1" dir="${2:-.}" file
  case "$commit" in
    *[!0-9a-f]*|'') fail "commit must be a full lowercase commit sha, got: ${commit}" ;;
  esac
  [ "${#commit}" -eq 40 ] || [ "${#commit}" -eq 64 ] || fail "commit must be a full commit sha, got: ${commit}"
  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || fail "commit needs the repository checked out (actions/checkout) at ${dir} to read its git note"
  echo "Reading the git note of ${commit}" >&2
  git -C "$dir" fetch origin "refs/notes/*:refs/notes/*" >&2
  file="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/note-${commit}.jsonl"
  git -C "$dir" notes show "$commit" > "$file" || fail "commit ${commit} has no git note"
  [ -s "$file" ] || fail "the git note of ${commit} is empty"
  printf '%s\n' "$file"
}

# attestation_input resolves the attestation to verify from
# INPUT_ATTESTATION or INPUT_COMMIT (with INPUT_PATH) and prints its path.
attestation_input() {
  local attestation="${INPUT_ATTESTATION:-}" commit="${INPUT_COMMIT:-}"
  if [ -n "$commit" ]; then
    [ -z "$attestation" ] || fail "give either attestation or commit, not both"
    attestation="$(note_attestation "$commit" "${INPUT_PATH:-.}")"
  fi
  [ -n "$attestation" ] || fail "attestation or commit is required"
  [ -e "$attestation" ] || fail "attestation not found: ${attestation}"
  printf '%s\n' "$attestation"
}

# add_flag appends "FLAG VALUE" to ARGS when VALUE is not empty.
add_flag() {
  [ -n "$2" ] && ARGS+=("$1" "$2")
  return 0
}

# add_bool appends FLAG to ARGS when VALUE is "true".
add_bool() {
  [ "$2" = "true" ] && ARGS+=("$1")
  return 0
}

# add_each appends "FLAG line" to ARGS for every line of VALUE.
add_each() {
  local line
  while IFS= read -r line; do
    ARGS+=("$1" "$line")
  done < <(lines "$2")
}

# add_param appends "--param NAME:VALUE" when VALUE is not empty.
add_param() {
  [ -n "$2" ] && ARGS+=("--param" "$1:$2")
  return 0
}

# add_list_param appends "--param NAME:[a,b,…]" from the lines of VALUE,
# when there are any.
add_list_param() {
  local joined="" line
  while IFS= read -r line; do
    joined="${joined:+${joined},}${line}"
  done < <(lines "$2")
  [ -n "$joined" ] && ARGS+=("--param" "$1:[${joined}]")
  return 0
}

# add_raw_args appends the whitespace-separated words of VALUE.
add_raw_args() {
  local word
  for word in $1; do
    ARGS+=("$word")
  done
}

# run_verification runs the verifier with ARGS, prints its output, writes
# it to the step summary under TITLE, and sets the result, level (the
# SLSA level a build or source verification computed), levels (the
# levels a VSA states) and, with VSA_PATH, vsa outputs. Exits 1 on a failed verification and 2
# when the verification could not run.
run_verification() {
  local verifier="$1" title="$2" out err code level levels
  out="$(mktemp)"; err="$(mktemp)"
  set +e
  "$verifier" "${ARGS[@]}" >"$out" 2>"$err"
  code=$?
  set -e

  cat "$out"
  cat "$err" >&2
  level="$(sed -n 's/^SLSA Level: \([0-9]*\).*/\1/p' "$out" | head -n1)"
  levels="$(sed -n 's/^ *Levels: *\(.*\)$/\1/p' "$out" | head -n1)"
  local result
  case "$code" in
    0) result=PASS ;;
    1) result=FAIL ;;
    *) result=ERROR ;;
  esac

  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
      echo "## ${title}: ${result}"
      echo
      echo '```'
      cat "$out"
      [ -s "$err" ] && cat "$err"
      echo '```'
    } >> "$GITHUB_STEP_SUMMARY"
  fi
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
      echo "result=${result}"
      echo "level=${level}"
      echo "levels=${levels}"
    } >> "$GITHUB_OUTPUT"
  fi

  if [ "$code" -eq 0 ] && [ -n "${VSA_PATH:-}" ]; then
    "$verifier" "${ARGS[@]}" --vsa > "$VSA_PATH"
    echo "Wrote VSA to ${VSA_PATH}" >&2
    [ -n "${GITHUB_OUTPUT:-}" ] && echo "vsa=${VSA_PATH}" >> "$GITHUB_OUTPUT"
  fi

  rm -f "$out" "$err"
  case "$code" in
    0) return 0 ;;
    1) echo "::error::${title} failed" >&2; exit 1 ;;
    *) echo "::error::${title} could not run (exit ${code})" >&2; exit 2 ;;
  esac
}

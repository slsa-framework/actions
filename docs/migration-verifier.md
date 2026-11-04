# Migrating from slsa-verifier

This is the consumer half of the [migration guide](migration.md): how to
replace slsa-verifier with the new
[slsa-verifier](https://github.com/slsa-framework/verifier) (same binary
name, new repository), on the command line and through the
[`verify/build`](../verify/build) action. Read
[What changed](migration.md#what-changed) first if you have not: the
producer side is in [Migrating from slsa-github-generator](migration-generator.md).

## The command line

The old verifier had one subcommand per thing to verify. The new one has one
per attestation type: `build`, `source` and `vsa`. Build provenance for an
artifact, from either generator, is verified with `build`.

Before:

```sh
slsa-verifier verify-artifact app-linux-amd64 \
  --provenance-path app-linux-amd64.intoto.jsonl \
  --source-uri github.com/example/app \
  --source-tag v1.0.3
```

After, for provenance from the new attester:

```sh
slsa-verifier build attestations.intoto.jsonl app-linux-amd64 \
  --param expected_source:github.com/example/app \
  --param expected_tag:v1.0.3 \
  --param 'trusted_builders:[https://github.com/example/app/.github/workflows/release.yml@refs/tags/v1.0.3]' \
  --signer 'sigstore::https://token.actions.githubusercontent.com::https://github.com/slsa-framework/actions/.github/workflows/attest_actions.yml@refs/tags/vX.Y.Z' \
  --require-signatures --level 3
```

The attestation file is the first argument and the artifacts follow. Flags
became parameters:

| Old flag | New form | Notes |
| --- | --- | --- |
| `--provenance-path FILE` | first positional argument | A file, a `.jsonl` file or a directory of attestations |
| `ARTIFACT...` | positional after the attestation | Hashed with the algorithms the subjects use |
| none | `-s algorithm:digest` | State a digest without the file, e.g. an image manifest |
| `--source-uri` | `--param expected_source:github.com/org/repo` | |
| `--source-tag` | `--param expected_tag:v1.2.3` | |
| `--source-branch` | `--param expected_branch:main` | |
| `--source-versioned-tag` | `--param expected_versioned_tag:v1` | |
| `--build-workflow-input k=v` | `--param 'expected_workflow_inputs:[k=v,...]'` | |
| `--builder-id ID` | `--param 'trusted_builders:[ID,...]'` | See below, an id without `@ref` trusts any ref |
| implicit signature check | `--require-signatures`, `--signer SPEC` | Opt in. `--signer` implies `--require-signatures` |
| implicit level 3 | `--level 3` | Default `0` evaluates every control. A level makes controls above it informative |
| `--print-provenance` | none | |
| `verify-image IMAGE@sha256:...` | `build FILE -s sha256:<digest>` | No registry fetching |
| `verify-npm-package` | none | |
| `verify-vsa` | `vsa` | Verifier bound with `--verifier id=SPEC`, levels with `--level` |

## What to name as the trusted builder

This is the one place the mental model shifts. With the generator, the
builder was the generator's workflow at a release tag and the verifier's
built-in list vouched for it. With the attester, the builder is your own
workflow and the signer is the observer:

- `trusted_builders` lists your workflow:
  `https://github.com/<you>/<repo>/.github/workflows/<workflow>.yml`, with
  `@refs/tags/vX.Y.Z` to pin a ref or without it to accept any.
- `--signer` pins the observer identity at the release the producer calls:
  `sigstore::https://token.actions.githubusercontent.com::https://github.com/slsa-framework/actions/.github/workflows/attest_actions.yml@refs/tags/vX.Y.Z`.

The verifier's builder registry already knows the `attest_actions.yml`
identity and binds the provenance's `builder.id` to it, so a provenance
claiming your workflow but signed by someone else fails the
`builder-identity-bound` control. The registry also knows the five generator
workflows, which is what makes old provenance verifiable with the same
command.

The identity spec is flexible to allow matching principals in different
ways, read the
[Principals documentation on the Policy Labs project](https://github.com/policylabs/signer/blob/main/docs/principals.md)
for more.

## The actions

The old installer action was replaced by `install/verifier`, which verifies
the verifier release against its own provenance before putting it on the
path:

```yaml
      - uses: slsa-framework/actions/install/verifier@<sha>
      - run: |
          slsa-verifier build attestations.intoto.jsonl app-linux-amd64 \
            --param expected_source:github.com/example/app \
            --param 'trusted_builders:[https://github.com/example/app/.github/workflows/release.yml]' \
            --require-signatures --level 3
```

Most workflows will not need the binary. `verify/build` wraps the command
with one input per parameter and fails the step on a `FAIL`:

```yaml
      - uses: slsa-framework/actions/verify/build@<sha>
        with:
          attestation: attestations.intoto.jsonl
          artifacts: |
            dist/app-linux-amd64
            dist/app-darwin-arm64
          expected-source: github.com/example/app
          expected-tag: ${{ github.ref_name }}
          trusted-builders: |
            https://github.com/example/app/.github/workflows/release.yml
          signer: sigstore::https://token.actions.githubusercontent.com::https://github.com/slsa-framework/actions/.github/workflows/attest_actions.yml@refs/tags/vX.Y.Z
          require-signatures: true
          level: 3
```

The action's `result` output is `PASS`, `FAIL` or `ERROR`, `level` carries
the level the provenance reached, and setting `vsa` makes it write a
Verification Summary Attestation for the result.

## Output and exit codes

The old verifier printed `PASSED: SLSA verification passed` or `FAILED: ...`
to stderr and exited 0 or 1. The new one prints `PASS` or `FAIL`, the level
reached, the subjects, and a roster of every control with its result. Exit
codes are 0 for pass, 1 for a failed verification and 2 for an execution
error such as a bad flag or an unreadable file. Scripts that grepped for
`PASSED` need updating while scripts that checked the exit code keep working,
with the new distinction between 1 and 2.

## Verifying provenance you already have

Provenance generated by slsa-github-generator stays valid, and the new
verifier reads it, both the v0.2 predicate and the v2.1.0 Sigstore bundles.
Verify it by naming the generator workflow as the trusted builder:

```sh
slsa-verifier build app.intoto.jsonl app-linux-amd64 \
  --param expected_source:github.com/example/app \
  --param expected_tag:v1.2.3 \
  --param 'trusted_builders:[https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@refs/tags/v2.1.0]' \
  --require-signatures --level 3
```

Because the registry binds each generator workflow to its own signing
identity, no `--signer` is needed for generator provenance. That lets a
consumer move to the new verifier first and keep accepting both kinds of
provenance while producers migrate at their own pace.

## Checklist

1. Install the verifier with `install/verifier` or from the
   [releases](https://github.com/slsa-framework/verifier/releases).
2. Rewrite `verify-artifact` calls as `build` calls, moving source flags to
   `--param expected_*` and `--builder-id` to `trusted_builders`.
3. Add `--require-signatures`, and `--signer` for attester provenance.
4. Update scripts that parsed `PASSED` or expected only exit codes 0 and 1.

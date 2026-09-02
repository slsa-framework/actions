# verify/build

Verifies a SLSA build provenance attestation with
[slsa-verifier](https://github.com/slsa-framework/verifier) `build`:
the signature, the identity of the builder that signed it, the artifacts
it is about, and the expectations you state.

```yaml
- uses: slsa-framework/actions/verify/build@<sha>
  with:
    attestation: provenance.intoto.jsonl
    artifacts: |
      dist/app-linux-amd64
      dist/app-darwin-arm64
    expected-source: github.com/example/app
    expected-tag: ${{ github.ref_name }}
    trusted-builders: |
      https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml
    require-signatures: true
    level: 3
```

The step fails when the verification fails (exit 1) or could not run
(exit 2); the roster is printed and added to the job summary either way.
With `continue-on-error: true` the `result` output tells which.

Every input maps onto a `slsa-verifier build` flag; list inputs take one
value per line. `trusted-builders` is required because the L2 control
needs it; an id without an `@ref` trusts the builder at any ref, and
whether the ref is a legitimate release is the builder binding's job.
Attestations from a builder the verifier knows (the slsa-github-generator
workflows, GitHub Actions workflows attesting their own builds) are bound
to their signer automatically; bind your own with `builder`, `builders`
or by naming its identity in `signer`.

## Inputs

| Input | Flag | Meaning |
|---|---|---|
| `attestation` | positional | Attestation file (required) |
| `artifacts` | positional | Artifact files the attestation must be about, one per line |
| `subjects` | `--subject` | Digests as `algorithm:digest`, one per line |
| `expected-source` | `--param expected_source` | Repository the artifacts were built from |
| `expected-branch`, `expected-tag`, `expected-versioned-tag` | `--param expected_*` | Triggering branch, exact tag, or semantic version |
| `expected-workflow-inputs` | `--param expected_workflow_inputs` | `name=value` per line |
| `trusted-builders` | `--param trusted_builders` | Builder ids, one per line (required) |
| `params` | `--param` | Further parameters, one per line |
| `signer` | `--signer` | Expected signer specs, one per line; implies `require-signatures` |
| `require-signatures` | `--require-signatures` | Fail unless a signature verified |
| `key` | `--key` | Public key files, one per line |
| `builder`, `builders` | `--builder`, `--builders` | Builder bindings and registry files |
| `level` | `--level` | Required SLSA build level, 1-3 |
| `spec` | `--spec` | SLSA spec version |
| `controls` | `--controls` | User-supplied controls |
| `skip-buildtype-checks` | `--skip-buildtype-checks` | Skip buildType checks with no expectation given |
| `verbose` | `--verbose` | Show skipped controls in the roster |
| `vsa` | `--vsa` | Write an unsigned VSA to this path on a pass |
| `verifier-id` | `--verifier-id` | `verifier.id` recorded in the VSA |
| `args` | | Further arguments, whitespace-separated |
| `version`, `repo` | | Which slsa-verifier release to use, verified against its provenance before it runs |

## Outputs

| Output | Meaning |
|---|---|
| `result` | `PASS`, `FAIL`, or `ERROR` |
| `level` | SLSA build level reached |
| `vsa` | Path of the VSA written, when requested and passed |

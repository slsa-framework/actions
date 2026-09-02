# verify/vsa

Verifies a SLSA Verification Summary Attestation with
[slsa-verifier](https://github.com/slsa-framework/verifier) `vsa`:
its signature, the verifier that issued it and the identity bound to
that verifier, the subjects it is about, and what it states.

```yaml
- uses: slsa-framework/actions/verify/vsa@<sha>
  with:
    attestation: app.vsa.sigstore.json
    artifacts: dist/app.tgz
    verifier: https://verify.example.com=sigstore::https://token.actions.githubusercontent.com::https://github.com/example/verifier/.github/workflows/verify.yml@refs/heads/main
    level: SLSA_BUILD_LEVEL_3
    resource: pkg:oci/example/app
```

A `verifier.id` is a claim written into the document, so a verifier is
accepted only together with the signer authorized to issue VSAs for it
(`id=<signer spec>`), a wildcard `signer`, or `allow-unbound-verifier`.
With `commit`, the VSA is read from the commit's git note, as sourcetool
stores it, and the commit is a subject the VSA must be about:

```yaml
- uses: actions/checkout@<sha>
  with:
    persist-credentials: false
- uses: slsa-framework/actions/verify/vsa@<sha>
  with:
    commit: ${{ github.sha }}
    verifier: https://github.com/slsa-framework/source-actions=sigstore(identityMatch=prefix)::https://token.actions.githubusercontent.com::https://github.com/slsa-framework/source-actions/.github/workflows/compute_slsa_source.yml@
    level: SLSA_SOURCE_LEVEL_1
```

The step fails when the verification fails (exit 1) or could not run
(exit 2); the report is printed and added to the job summary either way.
With `continue-on-error: true` the `result` output tells which.

## Inputs

| Input | Flag | Meaning |
|---|---|---|
| `attestation` | positional | VSA file; give this or `commit` |
| `commit`, `path` | note | Commit whose git note holds the VSA, in the checkout at `path`; also a subject |
| `artifacts` | positional | Artifact files the VSA must be about, one per line |
| `subjects` | `--subject` | Digests as `algorithm:digest`, one per line |
| `verifier` | `--verifier` | Accepted verifier ids, bound as `id=<signer spec>`, one per line (required) |
| `allow-unbound-verifier` | `--allow-unbound-verifier` | Accept a verifier with no authorized signer |
| `signer` | `--signer` | Wildcard signer specs, one per line |
| `require-signatures` | `--require-signatures` | Fail unless a signature verified |
| `key` | `--key` | Public key files, one per line |
| `level` | `--level` | Required levels, one per line, any satisfied |
| `resource`, `policy` | `--resource`, `--policy` | Expected resourceUri and policy.uri |
| `dependency` | `--dependency` | dependencyLevels keys that must be present |
| `args` | | Further arguments, whitespace-separated |
| `version`, `repo` | | Which slsa-verifier release to use, verified against its provenance before it runs |

## Outputs

| Output | Meaning |
|---|---|
| `result` | `PASS`, `FAIL`, or `ERROR` |
| `levels` | Levels the VSA states |

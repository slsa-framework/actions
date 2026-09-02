# verify/source

Verifies a SLSA source provenance attestation with
[slsa-verifier](https://github.com/slsa-framework/verifier) `source`:
its signature, the repository and branch (or tag) it is about, and the
SLSA source level it reaches.

The attestation comes from a file, or from the **git note** of a commit
of the checked-out repository — where the `slsa_with_provenance` action
and sourcetool store it — which is the usual way to verify the commit a
workflow is running on:

```yaml
- uses: actions/checkout@<sha>
  with:
    persist-credentials: false
- uses: slsa-framework/actions/verify/source@<sha>
  with:
    commit: ${{ github.sha }}
    expected-branch: refs/heads/main
    official: true
    level: 3
```

With `commit`, the note is fetched from `origin` and the commit is the
subject the attestation must be about; `expected-repo` defaults to the
repository the workflow runs in. A note holds every attestation stored
for the commit (source provenance, tag provenance, VSAs): the verifier
picks the source provenance about the commit, or the tag provenance
when `expected-tag` is given.

The step fails when the verification fails (exit 1) or could not run
(exit 2); the roster is printed and added to the job summary either way.
With `continue-on-error: true` the `result` output tells which.

## Inputs

| Input | Flag | Meaning |
|---|---|---|
| `attestation` | positional | Attestation file; give this or `commit` |
| `commit` | positional + note | Commit whose git note holds the attestation; also the subject |
| `path` | | Directory of the checkout whose notes to read; defaults to the workspace |
| `subject` | `--subject` | Commit the attestation must be about, when not given as `commit` |
| `expected-repo` | `--expected-repo` | Repository URI; defaults to the current repository |
| `expected-branch`, `expected-tag` | `--expected-branch`, `--expected-tag` | Branch ref or tag name |
| `official` | `--official` | Require the official SLSA source-actions signer |
| `signer` | `--signer` | Expected signer specs, one per line |
| `require-signatures` | `--require-signatures` | Fail unless a signature verified |
| `key` | `--key` | Public key files, one per line |
| `params` | `--param` | Further parameters, one per line |
| `level` | `--level` | Required SLSA source level, 1-4 |
| `since` | `--since` | Controls must have been active since this date |
| `spec` | `--spec` | SLSA spec version |
| `controls` | `--controls` | User-supplied controls |
| `verbose` | `--verbose` | Show skipped controls in the roster |
| `vsa` | `--vsa` | Write an unsigned VSA to this path on a pass |
| `verifier-id` | `--verifier-id` | `verifier.id` recorded in the VSA |
| `args` | | Further arguments, whitespace-separated |
| `version`, `repo` | | Which slsa-verifier release to use, verified against its provenance before it runs |

## Outputs

| Output | Meaning |
|---|---|
| `result` | `PASS`, `FAIL`, or `ERROR` |
| `level` | SLSA source level reached |
| `vsa` | Path of the VSA written, when requested and passed |

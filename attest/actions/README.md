# SLSA Build Provenance Attester

Watches a GitHub Actions workflow run, waits for its jobs to complete and
generates a signed SLSA build provenance attestation
(`https://slsa.dev/buildtypes/watcher/v1`) over the run's artifacts using
[slsa-attester](https://github.com/slsa-framework/slsa-attester).

There are two ways to use it:

## As a job (trusted builder identity)

Add the reusable workflow as a job to the workflow you want attested. The
attester waits for every other job in the run, collects their artifacts and
attests them. Signing happens inside the reusable workflow, so the sigstore
certificate identifies the `slsa-framework/actions` workflow as the signer —
the attestation carries a builder identity independent of the calling
workflow, the way slsa-github-generator worked.

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      # ... build and upload your artifacts ...

  provenance:
    permissions:
      id-token: write
      actions: read
      contents: read
    uses: slsa-framework/actions/.github/workflows/attest_actions.yml@main
```

## As a step (convenience)

Add the action as the last step of a job. The attester watches the run it is
part of, excluding its own job, and waits for every sibling job before
attesting. The attestation is signed with the calling workflow's own identity.

```yaml
jobs:
  build:
    permissions:
      id-token: write
      actions: read
      contents: read
    runs-on: ubuntu-latest
    steps:
      # ... build and upload your artifacts ...
      - name: Attest the build
        uses: slsa-framework/actions/attest/actions@main
```

## Inputs

| Input | Default | Description |
| --- | --- | --- |
| `run-spec` | current run | Run to attest as `github://owner/repo/runID` (step form only) |
| `sign` | `true` | Sign with the job's workload identity (sigstore) |
| `output` | `provenance.intoto.json` | Where to write the attestation |
| `watch-jobs` | all jobs | Comma-separated job names to watch |
| `timeout` | `20m` | Max wait for the watched jobs (Go duration; `0` disables) |
| `collect-artifacts` | `true` | Collect the run's artifacts as subjects |
| `expand-artifacts` | `true` | Attest one subject per file inside each artifact archive |
| `artifacts-filter` | none | Comma-separated globs; only matching artifacts are attested |
| `dependencies` | none | Extra resolved dependencies (resource descriptor shorthand) |
| `subjects` | none | Extra subjects as `algorithm:digest` |
| `build-from-source` | `true` | Build slsa-attester from source (until releases are published) |
| `version` | none | slsa-attester release to download (once available) |

The subjects declared with `subjects` use the same `algorithm:digest` syntax
the [slsa verifier](https://github.com/slsa-framework/verifier) accepts, so
digests attested here can be restated verbatim at verification time.

# SLSA Build Provenance Attester

Watches a GitHub Actions workflow run, waits for its jobs to complete and
generates a signed SLSA build provenance attestation
(`https://slsa.dev/buildtypes/watcher/v1`) over the run's artifacts using
[slsa-attester](https://github.com/slsa-framework/attester).

## Usage

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

### Why the attestation must run in its own job

Anything that executes earlier in a job — build scripts, dependencies, test
code — runs before the attester and can tamper with the runner: replace the
attester binary, poison the tool cache, rewrite `PATH`. An attestation
generated as the last step of a build job can therefore be forged by the very
process it attests. And the risk is not limited to earlier steps: every step
in a job shares the OIDC workload identity the attestation is signed with, so
any other step could mint an equally-valid signature of its own. The attester
enforces this: before watching, it inspects its own job through the jobs API
and refuses to run if the job contains any step besides its own.

The action can also be called directly, as long as it gets a job of its own —
the only difference is identity: a direct call signs the attestation with the
calling workflow's identity instead of the trusted `slsa-framework/actions`
identity, so verifiers must be pointed at your workflow.

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
    runs-on: ubuntu-latest
    steps:
      # No other steps in this job: the attester refuses shared jobs.
      - uses: slsa-framework/actions/attest/actions@main
```

Setting `unsafe-shared-job: true` disables the check. Don't: an attestation
from a shared job proves nothing, since the build could have forged it.

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
| `artifacts-filter` | none | Comma-separated globs; only matching artifacts/assets are attested |
| `release` | none | Also attest the assets of this release tag (for runs publishing to a GitHub release) |
| `sboms` | none | Comma-separated collector sources to fetch SBOMs from; their top-level elements become subjects |
| `dependencies` | none | Extra resolved dependencies (resource descriptor shorthand) |
| `subjects` | none | Extra subjects as `algorithm:digest` |
| `base64-subjects` | none | Base64-encoded sha256sum-format checksums file (slsa-github-generator compatible) |
| `build-from-source` | `true` | Build slsa-attester from source (until releases are published) |
| `version` | none | slsa-attester release to download (once available) |
| `unsafe-shared-job` | `false` | Attest even when other steps already ran in this job (unsafe; see above) |

The subjects declared with `subjects` use the same `algorithm:digest` syntax
the [slsa verifier](https://github.com/slsa-framework/verifier) accepts, so
digests attested here can be restated verbatim at verification time.

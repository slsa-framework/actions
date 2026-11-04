# Migrating from slsa-github-generator

This is the producer half of the [migration guide](migration.md): how to
replace each slsa-github-generator reusable workflow with the
[`attest_actions.yml`](../.github/workflows/attest_actions.yml) reusable
workflow of this repository, backed by
[slsa-attester](https://github.com/slsa-framework/attester). Read
[What changed](migration.md#what-changed) first if you have not; the
consumer side is in [Migrating from slsa-verifier](migration-verifier.md).

## Generic generator

Before, with the generic generator:

```yaml
jobs:
  build:
    outputs:
      hashes: ${{ steps.hash.outputs.hashes }}
    runs-on: ubuntu-latest
    steps:
      - name: Build artifacts
        run: make dist
      - name: Generate hashes
        id: hash
        run: echo "hashes=$(sha256sum dist/* | base64 -w0)" >> "$GITHUB_OUTPUT"
      - uses: actions/upload-artifact@v4
        with:
          name: dist
          path: dist/

  provenance:
    needs: [build]
    permissions:
      actions: read
      id-token: write
      contents: write
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0
    with:
      base64-subjects: "${{ needs.build.outputs.hashes }}"
      upload-assets: true
```

After, with the attester:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Build artifacts
        run: make dist
      - uses: actions/upload-artifact@v4
        with:
          name: dist
          path: dist/

  provenance:
    permissions:
      id-token: write   # sigstore keyless signing
      actions: read     # read the run's jobs and artifacts
      contents: read
    uses: slsa-framework/actions/.github/workflows/attest_actions.yml@vX.Y.Z
```

What went away:

- The `hashes` output and the `sha256sum | base64` step. Every file inside
  every artifact the run uploaded becomes a subject, named
  `<artifact>/<path inside it>`. Set `expand-artifacts: false` to attest each
  artifact archive as a single subject instead, and `artifacts-filter` with
  globs to pick artifacts by name.
- `needs: [build]`. The attester waits for every other job in the run, so
  the dependency is implicit. Keeping `needs` is harmless. To wait for a
  subset of jobs, list them in `watch-jobs`.
- `contents: write`. The attester does not upload to releases. See
  [Where the provenance ends up](#where-the-provenance-ends-up).
- `private-repository`. The attester signs private repositories the same way
  as public ones. The Rekor entry still records the signing identity, which
  includes the repository name, as it did before.

If you would rather not change how subjects are declared yet, the old
`hashes` output can be passed straight through:

```yaml
    uses: slsa-framework/actions/.github/workflows/attest_actions.yml@vX.Y.Z
    with:
      collect-artifacts: "false"
      base64-subjects: "${{ needs.build.outputs.hashes }}"
```

## Go builder

The Go builder compiled your binary from `.slsa-goreleaser.yml`. There is no
replacement for that step: build the binary yourself, with `go build`, a
goreleaser job or whatever you prefer, and let the attester observe the run.
The ldflags you used to compute in an `args` job and hand over as
`evaluated-envs` move into the build job itself, since nothing has to
pass them across a trust boundary any more.

A release workflow that publishes with goreleaser looks like this. The
release assets, including SBOMs and checksums, are attested straight from
the release:

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    outputs:
      tag_name: ${{ steps.tag.outputs.tag_name }}
    steps:
      - uses: actions/checkout@v7
        with:
          persist-credentials: false
      - uses: actions/setup-go@v7
        with:
          go-version-file: go.mod
      - id: tag
        run: echo "tag_name=${GITHUB_REF#refs/*/}" >> "$GITHUB_OUTPUT"
      - uses: goreleaser/goreleaser-action@v7
        with:
          args: release --clean
        env:
          GITHUB_TOKEN: ${{ github.token }}

  provenance:
    needs: [release]
    permissions:
      id-token: write
      actions: read
      contents: read
    uses: slsa-framework/actions/.github/workflows/attest_actions.yml@vX.Y.Z
    with:
      watch-jobs: release
      collect-artifacts: "false"
      release: ${{ needs.release.outputs.tag_name }}
```

The digests of release assets come from GitHub, which records them at upload
time. Assets uploaded before GitHub computed digests are downloaded and
hashed by the attester.

Multi-platform builds no longer need one generator job per target. One
attester job covers every artifact the run produced, whichever job or matrix
leg produced it.

## Container generator

The container generator took an image name and digest and attached a cosign
attestation to the image in the registry. The attester attests any digest
you hand it, so an image is a subject like any other:

```yaml
jobs:
  image:
    runs-on: ubuntu-latest
    outputs:
      digest: ${{ steps.push.outputs.digest }}
    steps:
      # ... build and push the image with docker/build-push-action ...

  provenance:
    needs: [image]
    permissions:
      id-token: write
      actions: read
      contents: read
    uses: slsa-framework/actions/.github/workflows/attest_actions.yml@vX.Y.Z
    with:
      collect-artifacts: "false"
      subjects: sha256:${{ needs.image.outputs.digest }}
```

Note the current gap: the attester writes the attestation to a file and
uploads it as a workflow artifact. It does not push it to the registry.
If your consumers expect the attestation next to the image, attach the
file yourself with cosign or oras in a later job. To verify an image,
pass the attestation file and the manifest digest with
`--subject sha256:<digest>`, the verifier does not fetch attestations
from registries yet.

## Node.js builder

There is no equivalent of the Node.js builder yet. The attester can attest
the tarball `npm pack` produces like any other artifact, but the verifier has
no `verify-npm-package` command and the attester does not publish to npm. If
you rely on npm's own provenance verification, keep `npm publish --provenance`
for now.

## Input mapping

| slsa-github-generator input | attest_actions.yml input | Notes |
| --- | --- | --- |
| `base64-subjects` | `base64-subjects` | Same format. Defaults to off since artifacts are collected automatically |
| `base64-subjects-as-file` | none | Upload the file as an artifact instead, the attester hashes it |
| `provenance-name` | `artifact-name` | Names the uploaded workflow artifact, not the file inside it (see below) |
| `upload-assets`, `upload-tag-name`, `draft-release`, `prerelease` | none | Upload the attestation in a job of your own |
| `private-repository`, `rekor-log-public` | none | Not needed |
| `continue-on-error` | none | Use GitHub's own `continue-on-error` on the job |
| `compile-generator`, `compile-builder` | `build-from-source` | Builds the attester from its repository tip. (Defaults to `true` today pass `false` with `version` to use a verified release) |
| `go-version`, `config-file`, `evaluated-envs` | none | You run the build |
| `image`, `digest` | `subjects: sha256:<digest>` | See the container section |
| `registry-*`, `provenance-repository` | none | No registry access |
| none | `watch-jobs` | Wait only for the named jobs |
| none | `collect-artifacts`, `expand-artifacts`, `artifacts-filter` | Artifact collection |
| none | `release` | Attest the assets of a release tag |
| none | `sboms` | Attest the top-level elements of SBOMs |
| none | `subjects`, `dependencies` | Explicit digests and extra resolved dependencies |
| none | `timeout` | Max wait for the watched jobs, default 20 minutes |

## Permissions

| Permission | Generator | Attester | Why |
| --- | --- | --- | --- |
| `id-token: write` | yes | yes | Sigstore keyless signing |
| `actions: read` | yes | yes | Read the run's jobs and artifacts |
| `contents: read` | sometimes | yes | Read the repository |
| `contents: write` | for `upload-assets` | no | Upload in your own job if needed |
| `packages: write` | container generator | no | No registry access |

The job that calls the reusable workflow needs nothing else. If you call the
`attest/actions` composite action directly instead of the reusable workflow,
it must be the only step in its job. The attester inspects its own job through
the API and refuses to run next to other steps, because any earlier step could
replace the attester and any step shares the signing identity.

## Where the provenance ends up

The generator uploaded `<subject>.intoto.jsonl` (or `multiple.intoto.jsonl`,
or `provenance-name`) as a workflow artifact and, with `upload-assets`, as a
release asset. The attester uploads a workflow artifact named
`slsa-attestations` (configurable with `artifact-name`) containing
`provenance.intoto.json`, and prints the statement to the job summary.

To publish it to a release, add a job after the provenance job. The
convention the SLSA tools follow is to name the release asset
`attestations.intoto.jsonl`: the install and verify actions in this
repository look for that name when they verify their own releases:

```yaml
  publish:
    needs: [release, provenance]
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/download-artifact@v7
        with:
          name: slsa-attestations
      - run: |
          mv provenance.intoto.json attestations.intoto.jsonl
          gh release upload "${TAG}" attestations.intoto.jsonl --repo "${GITHUB_REPOSITORY}"
        env:
          TAG: ${{ needs.release.outputs.tag_name }}
          GH_TOKEN: ${{ github.token }}
```

The file is a Sigstore bundle holding a DSSE envelope, one JSON object per
line, so it drops into any tool that read the generator's `.intoto.jsonl`
files from v2.1.0 on. Generator releases before v2.1.0 wrote a bare DSSE
envelope, the new verifier reads both.

## Pinning and versions

Call the attester workflow at a release tag, as you called the generator.
__Never call it at a branch__. The ref in the `uses:` line is the ref the
signing certificate records as the observer's identity, so a branch ref
would let any future commit on that branch sign provenance under the same
name, and a verifier could not tell which attester code ran. A tag names a
fixed commit, and the [releases](https://github.com/slsa-framework/actions/releases)
of this repository are what verifiers are told to trust.

The ref appears in two places that must agree:

- the `uses:` line, `attest_actions.yml@vX.Y.Z`
- the signer identity consumers pin, `attest_actions.yml@refs/tags/vX.Y.Z`

Pinning to a commit SHA works too, and is what Dependabot and Renovate keep
current. The identity then carries the SHA, so the signer consumers pin
becomes `attest_actions.yml@<sha>`. Whichever form you choose, tell your
consumers, since an exact signer match fails on any other ref. The
verifier's builder registry binds `builder.id` to the attester identity at
any ref, so a consumer that relies on the registry and `--require-signatures`
alone keeps verifying across your upgrades, one that pins `--signer` has to
move with you.

## Checklist

1. Replace the `uses:` line with
   `slsa-framework/actions/.github/workflows/attest_actions.yml@vX.Y.Z`,
   pinned to a [release](https://github.com/slsa-framework/actions/releases)
   and never to a branch, and drop `with:` inputs the mapping table marks
   as gone.
2. Change the job's permissions to `id-token: write`, `actions: read`,
   `contents: read`.
3. Remove the hash-computing step and its job output, or keep the output and
   pass it as `base64-subjects` with `collect-artifacts: "false"`.
4. If you used the Go builder, add a build job of your own.
5. If you uploaded provenance to releases, add a publish job that renames
   `provenance.intoto.json` to `attestations.intoto.jsonl` and uploads it.
6. Tell consumers the trusted builder is now your workflow and the signer is
   `attest_actions.yml`. The [consumer guide](migration-verifier.md) says
   what they do with that.

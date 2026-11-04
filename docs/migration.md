# Migrating from slsa-github-generator and slsa-verifier

[slsa-github-generator](https://github.com/slsa-framework/slsa-github-generator)
and [slsa-verifier](https://github.com/slsa-framework/slsa-verifier) are no
longer actively maintained (both repositories published a notice to that effect
since August 2026. The last generator release was v2.1.0 and the last verifier
release was v2.7.1). Their replacements are the official SLSA actions in this
repository, backed by two new tools:

- [slsa-attester](https://github.com/slsa-framework/attester) generates build
  provenance. In GitHub Actions it runs through the
  [`attest_actions.yml`](../.github/workflows/attest_actions.yml) reusable
  workflow, which replaces the generator's reusable workflows.
- [slsa-verifier](https://github.com/slsa-framework/verifier) (same binary
  name, new repository) verifies build provenance, source provenance and
  VSAs. It runs through the [`verify/build`](../verify/build),
  [`verify/source`](../verify/source) and [`verify/vsa`](../verify/vsa)
  actions, or from the command line after
  [`install/verifier`](../install/verifier).

This guide covers the move in three parts: this introduction, a
[producer guide](migration-generator.md) for moving off
slsa-github-generator and a [consumer guide](migration-verifier.md) for
moving off slsa-verifier. Producers can migrate
without waiting for their consumers: the new verifier reads provenance from
the old generator, and the old verifier keeps working on provenance that
already exists. Consumers can likewise switch verifiers before any producer
has moved. See [Verifying provenance you already have](migration-verifier.md#verifying-provenance-you-already-have).

## What changed

There are four differences in how the new tools work that are important to
understand when migrating.

### The attester observes, it does not build

The old generator's Go and container builders compiled your project inside their
own reusable workflow. The new attester never touches your build. It runs as a
job of its own in your workflow, waits for the other jobs to finish, and attests
what they produced. Your existing build steps, goreleaser configuration or Docker
build stay as they are.

### Subjects can now be collected, not only declared

The generic generator needed a `base64-subjects` string you assembled with
`sha256sum | base64`. The attester downloads the artifacts your jobs uploaded with
`actions/upload-artifact` and hashes them itself. It can also read a GitHub
release's assets and the top-level elements of an SBOM. The `base64-subjects`
input still exists, with the same format, for drop-in moves.

### The provenance names your workflow as the builder

The old generator provenance carried `builder.id` =
`https://github.com/slsa-framework/slsa-github-generator/.github/workflows/<builder>.yml@refs/tags/vX.Y.Z`.
The new attester provenance carries `builder.id` =
`https://github.com/<you>/<repo>/.github/workflows/<workflow>.yml@<ref>`, the
workflow it watched, and is signed by the `attest_actions.yml` identity of
the official SLSA repository, which acts as the observer. The predicate is SLSA
provenance v1 with build type `https://slsa.dev/buildtypes/watcher/v1`, in place
of the generator's v0.2 predicate and `.../slsa-github-generator/generic@v1` build
types. The verifier knows both, so the change matters mostly for what you
pass as the trusted builder when verifying.

### Verification is explicit

The old verifier always checked the Sigstore signature and carried a built-in
list of trusted generator workflows. The new one evaluates a catalog of controls
against the provenance and reports a level. Signatures are checked when you ask
with `--require-signatures` or `--signer`, and the trusted builders are always
yours to name. Flags moved too: `--source-uri` and friends became parameters
(`expected_source`, `expected_tag` and so on) and the action exposes them as inputs.

## Where to go next

- [Migrating from slsa-github-generator](migration-generator.md): the
  generic, Go, container and Node.js workflows, input and permission
  mappings, where the provenance ends up, pinning, and a producer checklist.
- [Migrating from slsa-verifier](migration-verifier.md): the command line,
  the trusted builder model, the verify actions, output and exit codes,
  verifying provenance you already have, and a consumer checklist.

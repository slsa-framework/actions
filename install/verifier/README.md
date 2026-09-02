# install/verifier

Installs [slsa-verifier](https://github.com/slsa-framework/verifier)
into the runner and adds it to the `PATH`, verifying the release before
trusting it.

```yaml
- uses: slsa-framework/actions/install/verifier@<sha>
  with:
    version: v0.1.0        # optional; defaults to the release the action pins
- run: slsa-verifier build --require-signatures provenance.intoto.jsonl app.tgz
```

## How the release is verified

The action does not trust a download because it came from GitHub. Before
installing, the [AMPEL](https://github.com/carabiner-dev/ampel) policy
engine — bootstrapped by its own checksum-pinned installer — evaluates
the release's published `attestations.jsonl` against a pinned policy,
requiring that

- the binary is a subject of the provenance,
- the provenance names the repository's `release.yaml` workflow as the
  builder, and
- it was signed by that workflow running at the requested tag (Sigstore
  identity from GitHub's OIDC issuer).

Only then is the binary installed. A new release is adopted by bumping
`DEFAULT_VERSION` in `download.sh` and the default `version` of the
actions.

## Inputs

| Input | Default | Meaning |
|---|---|---|
| `version` | the release the action pins | Release tag to install |
| `install-dir` | `$HOME/.slsa` | Install directory; the binary lands in its `bin/` |
| `repo` | `slsa-framework/verifier` | Repository publishing the releases |
| `verify` | `true` | Verify the release against its provenance before installing |

## Outputs

| Output | Meaning |
|---|---|
| `path` | Absolute path of the installed binary |
| `bin-dir` | Directory added to the `PATH` |
| `version` | Release that was installed |

The `verify/*` actions run this script themselves, so a workflow that
uses them does not need this action.

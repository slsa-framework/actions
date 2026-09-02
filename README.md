# SLSA actions

GitHub Actions for producing and verifying SLSA attestations.

| Action | Purpose |
|---|---|
| [`slsa_with_provenance`](slsa_with_provenance) | Generates SLSA source provenance for a push, with the SLSA Source Tool |
| [`store_note`](store_note), [`get_note`](get_note) | Store and read attestations in the commit's git notes |
| [`install/verifier`](install/verifier) | Installs [slsa-verifier](https://github.com/slsa-framework/verifier), verified against its own release provenance |
| [`verify/build`](verify/build) | Verifies a SLSA build provenance attestation and the artifacts it is about |
| [`verify/source`](verify/source) | Verifies a SLSA source provenance attestation, from a file or a commit's git note |
| [`verify/vsa`](verify/vsa) | Verifies a SLSA Verification Summary Attestation and the verifier that issued it |

Every action is a composite action: pin it by commit SHA, pass inputs
through `with:`, and see each action's README for its inputs and outputs.

# GitHub Actions bootstrap access

This Terraform root establishes the narrow control-plane role used by the protected `infra-bootstrap` GitHub environment. It does not manage the application dev root and must never be applied locally.

The first apply runs in GitHub Actions from `main` with temporary STS credentials stored only in the protected environment. After that apply, the temporary credentials are deleted and all future runs use the created OIDC role.

The bootstrap role can:

- read and write only the bootstrap and bootstrap-access state objects and locks;
- read itself without modifying or deleting itself;
- manage inline policies and trust only for the project plan and deploy roles; and
- read the existing GitHub OIDC provider.

The root also adds supplemental budget tag permissions required by provider-backed dev plans. The automatic cost guard and application resources are unaffected.

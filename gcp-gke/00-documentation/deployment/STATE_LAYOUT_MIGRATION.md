# GKE live-layout and remote-state migration notes

**Status:** Required guardrails for future structural changes  
**Scope:** `gcp-gke/04-live`

## State identity is independent of directory numbering

The shared live root at `04-live/root.hcl` maps physical live-unit directory names to stable logical backend keys. The GCS prefix remains:

```text
gcp-gke/<client>/<environment>/<logical-layer>/terraform.tfstate
```

| Live directory | Stable logical key |
|---|---|
| `00-bootstrap` | `bootstrap` |
| `01-network` | `network` |
| `02-gke` | `gke` |
| `03-artifact-registry` | `artifact-registry` |
| `04-storage` | `storage` |
| `05-monitoring` | `monitoring` |
| `06-jenkins` | `jenkins` |
| `07-applications` | `applications` |

Do not replace this mapping with `basename(path)`, `path_relative_to_include()`, or another directory-derived prefix. A folder rename must not silently select a new backend object.

## Required procedure before any future rename

1. Record the current branch, commit SHA, client/environment, and all current GCS state object names.
2. Capture baseline plans for each affected live unit and retain them securely outside Git.
3. Change the live folder name and update every affected `include`, `dependency.config_path`, `dependencies.paths`, module source, config/chart/script reference, scaffold template, Docker instruction, and runbook reference.
4. Keep the logical key mapping unchanged unless a separately approved state migration is explicitly planned.
5. Compare the before/after backend bucket and prefix for every live unit. They must be identical for a folder-only refactor.
6. Compare plans. No existing VPC, subnet, Cloud NAT, GKE cluster/node pool, Artifact Registry repository, Filestore/StorageClass, Jenkins, or application resource may be proposed for unintended replacement, deletion, or recreation.
7. Run `07-tests/run_tests.sh`, Terraform/Terragrunt formatting checks, then a fresh per-layer plan review.
8. Do not run `init -migrate-state`, `state mv`, `state rm`, `import`, or any apply as part of a folder-only rename without explicit approval and a documented state-recovery plan.

## Historical files

`17-tmp-backup` is retained as historical material. Do not rewrite or delete it as part of a live-layout cleanup. The top-level `gcp-gke/root.hcl` remains for legacy/archive compatibility; active units under `04-live` must resolve `04-live/root.hcl`.

## Validation boundary

Static checks can prove that expected paths and stable prefix mappings are present. They cannot prove that a remote state object exists, that credentials can access it, or that a real plan is non-destructive. Those checks require an operator-run, read-only GCP/Terraform validation against the intended project.

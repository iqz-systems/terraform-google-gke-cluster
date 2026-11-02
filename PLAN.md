# Project Plan

## Overview

This repository is a reusable Terraform module, published to the Terraform registry as `iqz-systems/gke-cluster/google`, that creates a Google Kubernetes Engine cluster with Workload Identity, a dedicated node service account and separately managed node pools. The current goals are to fix the defects found in the review of 2026-11-01 without breaking existing callers, to expose the outputs and settings that callers need, to add repository tooling that keeps the module and its documentation consistent, and to prepare a deliberate major release for the changes that cannot be made compatibly.

## Technology Decisions

| Layer | Choice | Rationale |
| ----- | ------ | --------- |
| Infrastructure language | Terraform (HCL) | The module is consumed from the Terraform registry by Terraform configurations. |
| Provider | `hashicorp/google` `>=7.12.0` | Required for `secret_sync_config` and the other cluster attributes the module sets. |
| Node pool management | Separate `google_container_node_pool` resources, with the default pool removed | Node pools can be changed or replaced without recreating the cluster. |
| Networking | Dataplane V2 (`ADVANCED_DATAPATH`) with VPC-native IP allocation | Provides network policy enforcement without a separate add-on. |
| Identity | Workload Identity and a dedicated node service account | Workloads authenticate as Google service accounts without node-level keys. |
| Tests | `terraform test` with `mock_provider "google"` and `command = plan` | The tests run without credentials or a GCP project. |

## Architecture Overview

The calling configuration supplies the inputs. The module resolves the project through the `google_project` data source and uses that project ID for every resource. It creates a node service account with project IAM roles, an optional VPC network, the GKE cluster, and one node pool for each entry in `node_pools`. Every node pool runs as the node service account. The module currently outputs only the service account email and ID.

![Architecture](docs/diagrams/architecture.drawio.svg)

## Notes

- 2024-01-25: Node pools take their own zones through `node_pool_node_zones`, separate from the cluster's `cluster_node_zones`.
- 2025-01-13: The module can create its own VPC network or use an existing one through `create_vpc_network` and `vpc_network`.
- 2025-02-25: The default maintenance window is Saturday and Sunday from 02:00 to 08:00 UTC, and it can be removed by setting `maintenance_window` to null.
- 2025-12-08: The Gateway API is enabled on the standard channel by default.
- 2026-10-19: New attributes on `node_pools` are declared with `optional(..., default)`, so that existing callers keep working without changes. New inputs will follow the same rule, and their defaults will reproduce the current behaviour.
- 2026-11-01: Changes that would break existing callers (F11, F12) are held for a single major release, so that callers migrate once. All other backlog items will be released as minor versions. The user approved this plan and release grouping on 2026-11-01.
- 2026-11-01: For F2, a missing `vpc_network` with `create_vpc_network = false` will be a hard error from a precondition on the cluster, while a `vpc_network` ignored because `create_vpc_network = true` will produce a warning from a `check` block. A hard error in the second case would break existing callers' plans. A precondition is used instead of a cross-variable validation, which would require Terraform 1.9; the `check` block requires Terraform 1.5, which is below the 1.7 already required by the tests.
- 2026-11-01: F3 was first recorded as a defect, on the assumption that a long service account ID would plan successfully and fail at apply. The test run showed that the google provider rejects it at plan time, so F3 is a feature that lets callers with long cluster names set the ID. The module adds no check of its own for the derived ID, because the provider's validation runs before any module precondition and already names the invalid value.
- 2026-11-01: F4 is folded into F12. The module-created network is auto-mode, so adding a managed subnetwork would force the network, and the cluster with it, to be replaced; a usable network would also need a Cloud Router, Cloud NAT and firewall rules, which belong in a separate networking configuration. The user confirmed that every known caller sets `create_vpc_network = false`, so no interim change is needed and no state migration is planned.
- 2026-11-01: F6 removes `roles/storage.objectViewer` from the node service account without an opt-in input, because the user does not expect any workload to pull from Container Registry. If a workload still does, its new pods will fail with ImagePullBackOff after the change is applied, so the clusters that use the module will be checked for Container Registry images before release.
- 2026-11-01: F7 (removing the redundant OAuth scopes and the `disable-legacy-endpoints` metadata) was dropped. In provider 8.9.0, `oauth_scopes` and `metadata` in `node_config` are `ForceNew` and the node pool resource does not override this, so changing the scopes would replace every caller's node pools; omitting `oauth_scopes` would give new pools GKE's default scopes without `cloud-platform`. The change would not alter behaviour, so it does not justify a node pool replacement even in a major release. A comment in `gke.tf` records why the scopes are kept.
- 2026-11-01: F8 uses one optional `secondary_range_names` object with required `pods` and `services` attributes, instead of two separate inputs. In provider 8.9.0 each CIDR block field conflicts with both secondary range name fields, so the names must be supplied together, and the object type enforces that. All four fields are `ForceNew`, so the input is documented as applying to new clusters only.
- 2026-11-01: In F9, `shielded_instance_config` is emitted only when a pool sets `enable_secure_boot = true`, and `max_pods_per_node` defaults to null, because the provider marks both `ForceNew`; with the defaults, existing node pools are unchanged. Enabling either on an existing pool replaces that pool, which the README states. The `project` cluster label cannot be overridden through `resource_labels`.
- 2026-11-01: F14 was approved with `enable_cost_allocation` defaulting to null. `cost_management_config` is optional and computed in provider 8.9.0 and is updated in place, so omitting the block leaves the current setting untouched; a default of false would disable cost allocation on any cluster where it was enabled outside Terraform.

## Verification Plan

- Every change will be covered by plan-time tests in `tests/*.tftest.hcl`, run with `terraform init -backend=false && terraform test`. Each defect will first receive a test that fails against the current code, and the fix will be complete when that test passes.
- Input validation will be tested with `expect_failures = [var.<name>]`, including a passing case for each valid combination.
- Every change will pass `terraform fmt -check -recursive` and `terraform validate`. Once F10 is complete, these checks and the tests will also run in CI on every pull request.
- Behaviour that only the GCP API enforces, such as the service account ID length and the authorized networks block limit, will additionally be checked with `terraform plan -lock=false` from an example configuration against a non-production project before each release.
- The mock provider cannot populate the cluster's `master_auth` block, so the value of the `cluster_ca_certificate` output will be checked before each release with `terraform plan -lock=false` and `terraform output` from an example configuration against an existing non-production cluster.
- Before the release that contains F6, the container images running in the clusters that use the module will be listed (read only) to confirm that none is pulled from Container Registry storage, because the node service account no longer has `roles/storage.objectViewer`. This was checked on 2026-11-01 for every cluster known to use the module. The only private gcr.io-domain images are served from an Artifact Registry repository, which `roles/artifactregistry.reader` covers for clusters in the same project. One cluster pulls those images from another project through a grant that the module does not manage, so F6 does not affect it. The other gcr.io images are public Google images. No further check is needed unless a new cluster starts using the module before release.
- The README's Usage, Inputs and Outputs sections will be checked against `variables.tf` and `outputs.tf` for every change to an input or output.

## Backlog

> **Legend**: `[ ]` = not started, `[~]` = partially implemented, `[x]` = complete (move it to Completed)

### Defects


### Outputs and configuration


### Repository tooling

- [ ] F10: Add CI, documentation generation and examples. **Nothing exists**: there is no CI, no `examples/` directory, no CHANGELOG and no `required_version`. **Missing**: `required_version = ">= 1.7"` in `main.tf`; a GitHub Actions workflow running `terraform fmt -check -recursive`, `terraform validate`, `tflint` and `terraform test`; `terraform-docs` generating the README's Inputs and Outputs sections, with a CI check that the README is current; an `examples/basic` configuration that the registry will display; and a CHANGELOG. Simplify `deletion_protection = var.disable_deletion_protection == true ? false : true` to `!var.disable_deletion_protection`, and add descriptions to `subnetwork`, `private_cluster_config` and `master_authorized_networks_config`.

### Major release

- [ ] F11: Key node pools by name. **Exists**: `google_container_node_pool.node_pool` uses `count` over `var.node_pools`, so removing or reordering an entry recreates every pool after it. **Missing**: `for_each` keyed by `name`, release notes with the `terraform state mv` commands callers must run (for example from `module.gke_cluster.google_container_node_pool.node_pool[0]` to `module.gke_cluster.google_container_node_pool.node_pool["app-nodes"]`), and a test that removing the first pool leaves the second pool's address unchanged.
- [ ] F12: Rename `disable_deletion_protection` to `deletion_protection` (default `true`), and remove network creation (formerly F4): delete `create_vpc_network` and `google_compute_network.vpc_network`, make `vpc_network` and `subnetwork` required, and remove the `vpc_network_ignored` check and the cluster precondition that F2 added. The release notes will tell callers to delete `create_vpc_network = false` from their module call. **Nothing exists** beyond the current inputs.
- [ ] F13: Replace the deprecated default node pool removal. **Exists**: `gke.tf` sets `initial_node_count = 1` and `remove_default_node_pool = true`; with the resolved provider (`hashicorp/google` 8.9.0, allowed by `>=7.12.0`) every plan warns that `remove_default_node_pool` is deprecated and that clusters on 1.36.4-gke.1469000 or later should omit `initial_node_count` and `node_config` (or set `initial_node_count = 0`) instead. **Missing**: confirm the minimum cluster version callers run, decide whether the module's provider constraint should move to `>= 8`, switch to the new form, and check with a plan against an existing cluster that the change does not force the cluster to be replaced; if it does, keep it in this major release.

## Completed

- [x] F0a: Support for disabling deletion protection. Completed 2024-01-26.
- [x] F0b: Private nodes and per-node-pool zones. Completed 2024-01-25.
- [x] F0c: Service account ID output. Completed 2024-06-21.
- [x] F0d: Implied provider configuration. Completed 2024-08-21.
- [x] F0e: Optional VPC creation and existing VPC support. Completed 2025-01-13.
- [x] F0f: Private cluster configuration and master authorized networks. Completed 2025-01-23.
- [x] F0g: Weekend maintenance window. Completed 2025-02-25.
- [x] F0h: Subnetwork input. Completed 2025-03-26.
- [x] F0i: Gateway API enabled by default. Completed 2025-12-08.
- [x] F0j: Secret Manager add-on and secret sync configuration. Completed 2026-08-28.
- [x] F0k: Zonal clusters, node labels and taints, disk and image settings, initial node count, release channel, and plan-time tests. Completed 2026-10-19.
- [x] F1: Support more than one master authorized network. All entries in `master_authorized_networks_config` are now emitted as `cidr_blocks` inside a single `master_authorized_networks_config` block, which is omitted when the list is empty. Completed 2026-11-01.
- [x] F2: Validate the VPC network inputs. With `create_vpc_network = false` and no `vpc_network`, a precondition on the cluster now fails with a clear message; with `create_vpc_network = true` and `vpc_network` set, a `check` block warns that the value is ignored. The `network` expression no longer indexes an empty resource list. Completed 2026-11-01.
- [x] F3: Allow the node service account ID to be set. The optional `node_service_account_id` input overrides the default `<cluster_name>-sa`, so clusters with names longer than 27 characters can use the module; invalid values are rejected by a variable validation. Completed 2026-11-01.
- [x] F5: Add cluster outputs. The module now outputs `cluster_name`, `cluster_id`, `cluster_location`, `cluster_endpoint`, `cluster_ca_certificate` (sensitive), `network_name` and `node_pool_names`, documented in the README with an example `kubernetes` provider configuration. The value of `cluster_ca_certificate` remains to be checked against a real cluster before release, as set out in the Verification Plan. Completed 2026-11-01.
- [x] F6: Update the node service account roles. The node service account is granted `roles/container.defaultNodeServiceAccount` and `roles/artifactregistry.reader` through one `for_each` resource, `google_project_iam_member.k8s_sa_roles`; `roles/storage.objectViewer`, `roles/logging.logWriter` and `roles/monitoring.metricWriter` are no longer granted. The Container Registry check remains to be done before release, as set out in the Verification Plan. Completed 2026-11-01.
- [x] F8: Allow named secondary ranges for pods and services. The optional `secondary_range_names` object (`pods`, `services`) makes the cluster use existing secondary ranges instead of the `/16` and `/22` netmasks; it is documented as applying to new clusters only, because changing it replaces the cluster. Completed 2026-11-01.
- [x] F9: Expose fixed settings as optional inputs. Added `resource_labels` (merged, with the `project` label always set by the module), `logging_components`, and per-pool `max_surge`, `max_unavailable`, `max_pods_per_node` and `enable_secure_boot`, with validations for node counts, unique pool names and surge settings. All defaults reproduce the previous fixed values. Completed 2026-11-01.
- [x] F14: Add GKE cost allocation. The optional `enable_cost_allocation` input enables (true) or disables (false) `cost_management_config`; when it is null, the module leaves the setting unmanaged. Completed 2026-11-01.

## Next Steps

1. F10: CI, documentation generation, examples and `required_version`, so that the checks run on every pull request without depending on a local sandbox.
2. F13: confirm the minimum cluster version callers run and replace the deprecated `remove_default_node_pool` argument, which warns on every plan.

## Bugs Fixed During Verification

- 2026-11-01, F1: a plan with two or more entries in `master_authorized_networks_config` failed with "Too many master_authorized_networks_config blocks". **Cause**: `gke.tf` generated one `master_authorized_networks_config` block per list entry, and the provider allows at most one. **Fix**: a single block, present only when the list is non-empty, with a `dynamic "cidr_blocks"` over the list. **Test**: `multiple_authorized_networks` in `tests/master_authorized_networks.tftest.hcl` (with `no_authorized_networks_by_default` and `single_authorized_network` covering the other cases).
- 2026-11-01, F2: a plan with `create_vpc_network = false` and `vpc_network = null` failed with "Invalid index" on `google_compute_network.vpc_network.0.name`, and with `create_vpc_network = true` a supplied `vpc_network` was silently ignored. **Cause**: the `network` expression in `gke.tf` fell back to the module-created network whenever `vpc_network` was null, without checking `create_vpc_network`, and nothing validated the combination. **Fix**: `network` is selected by `create_vpc_network` alone, a cluster precondition requires `vpc_network` when `create_vpc_network` is false, and `check "vpc_network_ignored"` warns when the value is ignored. **Test**: `missing_vpc_network_rejected` and `ignored_vpc_network_warned` in `tests/network.tftest.hcl` (with `module_vpc_created_by_default` and `existing_vpc_used` covering the valid cases).
- 2026-11-01, F5: every test run failed with "Invalid index" on the new `cluster_ca_certificate` output. **Cause**: the output read `master_auth[0].cluster_ca_certificate`, and `master_auth` is an empty list during plan for a cluster that does not exist yet. **Fix**: the output uses `one(google_container_cluster.cluster.master_auth[*].cluster_ca_certificate)`, which is null while the list is empty. **Test**: `cluster_outputs` in `tests/outputs.tftest.hcl` asserts the output is null without an error while `master_auth` is empty; the full suite reproduced the failure.

## Changelog

- 2026-11-01: Created the plan from the module review, with the architecture diagram, backlog F1 to F12 and the completed history from git.
- 2026-11-01: Plan approved; F1 started with a reproducing test.
- 2026-11-01: Added F13 for the deprecated remove_default_node_pool argument reported by provider 8.9.0.
- 2026-11-01: F1 completed; all 10 test runs pass. See Bugs Fixed During Verification.
- 2026-11-01: F2 started with a reproducing test; recorded the precondition and check block decision in Notes.
- 2026-11-01: F2 completed; all 14 test runs pass. See Bugs Fixed During Verification.
- 2026-11-01: F3 started with a reproducing test.
- 2026-11-01: Reclassified F3 from a defect to a feature after the test run; the long-name test was removed because the provider already rejects the ID at plan time.
- 2026-11-01: F3 completed; all 18 test runs pass.
- 2026-11-01: F5 started; tests and outputs written.
- 2026-11-01: F5 completed; all 20 test runs pass. Added a manual release check for the CA certificate output, which the mock provider cannot populate.
- 2026-11-01: Folded F4 into F12 after the user confirmed no caller uses the module-created network.
- 2026-11-01: F6 started; storage.objectViewer removal moved from F12 into F6.
- 2026-11-01: F6 completed; all 21 test runs pass. Added the pre-release Container Registry image check to the Verification Plan.
- 2026-11-01: Recorded the result of the Container Registry image check for part of the clusters that use the module.
- 2026-11-01: Completed the Container Registry image check for the remaining clusters that use the module.
- 2026-11-01: Dropped F7 because changing node pool OAuth scopes forces node pool replacement.
- 2026-11-01: F8 started; tests and implementation written.
- 2026-11-01: F8 completed; all 23 test runs pass.
- 2026-11-01: F9 started; tests written and implementation delegated.
- 2026-11-01: F9 completed; all 29 test runs pass.
- 2026-11-01: Added F14 (GKE cost allocation), approved by the user; tests and implementation written.
- 2026-11-01: F14 completed; all 32 test runs pass.
- 2026-11-01: Removed the names of internal projects, clusters and workloads, because the repository is public.

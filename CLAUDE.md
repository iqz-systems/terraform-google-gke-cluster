# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A reusable Terraform module published to the Terraform registry as `iqz-systems/gke-cluster/google`. It creates a GKE cluster with Workload Identity, a dedicated node service account, and separately managed node pools. It requires the `hashicorp/google` provider `>=7.12.0` (pinned in `main.tf`). There is no root configuration, backend or state in this repo; consumers call it as a module.

## Commands

```sh
terraform init -backend=false        # once, before validate/test
terraform fmt -check -recursive      # formatting
terraform validate
terraform test                       # all runs in tests/, mocked google provider, no credentials needed
terraform test -filter=tests/node_pools.tftest.hcl -verbose
```

`terraform test` has no per-`run` filter; to focus on one run block, temporarily comment out the others or copy it into a scratch `.tftest.hcl`. All test runs use `command = plan` against `mock_provider "google"`, so assertions can only check planned/known values, and validation failures are tested with `expect_failures = [var.<name>]`.

## Architecture

- `main.tf`: provider requirement, the `google_project` data source (resolves `var.project_id`, falling back to the provider's project when null), the node service account, and its project IAM roles (`roles/container.defaultNodeServiceAccount` and `roles/artifactregistry.reader`, granted by one `for_each` resource). Every resource takes `project` from `data.google_project.current.project_id`, not from the variable directly.
- `gke.tf`: the optional VPC, the cluster, and the node pools.
  - The cluster is created with a throwaway default pool (`initial_node_count = 1`, `remove_default_node_pool = true`); real capacity lives only in `google_container_node_pool.node_pool`.
  - `location = var.cluster_region` on both the cluster and the node pools, so passing a zone there produces a zonal cluster. Per-pool zones come from `node_pool_node_zones`.
  - `network` is the module-created VPC (`google_compute_network.vpc_network[0]`) when `create_vpc_network` is true, otherwise `var.vpc_network`. A cluster precondition requires `vpc_network` when `create_vpc_network` is false, and `check "vpc_network_ignored"` warns when it is set but ignored. All known callers use an existing network, and network creation is planned for removal in the next major release.
  - Hard-coded, opinionated settings: Dataplane V2 (`ADVANCED_DATAPATH`), VPA, Gateway API standard channel, `/16` pod and `/22` service netmasks (unless `secondary_range_names` is set), `GKE_METADATA` workload metadata, GCFS, surge upgrades (1/0), auto-repair and auto-upgrade.
  - Node pools are created with `count` over `var.node_pools`, so they are addressed by list index. Reordering or removing an entry from the middle of the list forces recreation of the pools after it.
  - `lifecycle.ignore_changes` covers `node_count` and `initial_node_count` on pools and `node_version` on the cluster, because the autoscaler and release channel change them out of band.
- `variables.tf`: the `node_pools` object type uses `optional(..., default)` for newer attributes so existing callers stay compatible; input validation (taint effects, release channel) lives in `validation` blocks here.
- `tests/node_pools.tftest.hcl`: plan-time tests for node pool defaults/overrides and the validation rules.

## Conventions

- The README's Usage example, Inputs and Outputs sections are the module's user-facing documentation. Update them whenever a variable or output is added, changed or removed, and bump the `version` in the Usage example when releasing.
- New optional inputs should default to the current behaviour so the change is non-breaking for existing consumers.
- `.editorconfig`: 2-space indent, LF, final newline (4-space indent in Markdown).

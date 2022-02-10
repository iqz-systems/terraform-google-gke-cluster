# terraform-google-gke-cluster

Terraform module to create a Google Kubernetes Engine cluster with Workload Identity enabled. This module uses the [google](https://registry.terraform.io/providers/hashicorp/google/4.10.0) provider.

## Usage

```hcl
module "app_dbs" {
  source            = "iqz-systems/db-group/postgresql"
  version           = "1.0.0"
  username          = "app_db_user"
  db_names          = ["app_db1", "app_db2"]
  password_length   = 32
}
```

## Variables

- `db_names` set(string)
  - The names of databases to be created.
- `username` string
  - The database username to be created.
- `password_length` number
  - The length of the password to be created.
  - Default: `64`

## Outputs

- `db_names` list(string)
  - A set containing all names of the databases.
- `db_username` string
  - The username using which the database can be accessed.
- `db_password` string
  - The password associated with the user for the databases.

## Links

- [Terraform registry](https://registry.terraform.io/modules/iqz-systems/db-group/postgresql/latest)

# K8TRE GCP base infrastructure

Deploy GCP infrastructure using Terraform to support [K8TRE](https://github.com/k8tre/k8tre).

## Prerequisites

- Administrator access to a Google Cloud Platform project.
- Ideally you should have access to a domain name to setup a wildcard host, e.g. `*.k8tre.example.org`.

## First time

You must first create a GCS bucket to store the [Terraform state file](https://developer.hashicorp.com/terraform/language/state).
Activate your GCP credentials in your shell environment, edit the `google_storage_bucket.bucket` `name` in [`bootstrap/backend.tf`](bootstrap/backend.tf), then:

```sh
cd bootstrap
terraform init
terraform apply
cd ..
```

## Deploy Google Kubernetes Engine (GKE)

By default this will deploy two GKE clusters:

- `k8tre-dev-argocd` is where ArgoCD will run
- `k8tre-dev` is where K8TRE will be deployed

GCP Workload Identity is setup to allow ArgoCD running in the `k8tre-dev-argocd` cluster to have admin access to the `k8tre-dev` cluster.

### Configuration

Edit [`provider.tf`](provider.tf).
You must modify `terraform.backend.gcs` `bucket` to match the one in `bootstrap/backend.tf`.

You can install K8TRE GCP with no changes, but you will most likely want to set some variables.
Either modify [`variables.tf`](variables.tf), or copy [`overrides.tfvars-example`](overrides.tfvars-example) to `overrides.tfvars` and edit.

Particularly important variables include

- `project_id`: Your GCP Project ID
- `region`: GCP region, e.g. `europe-west2`
- `dns_domain`: The domain for K8TRE, e.g. `k8tre.example.org`
- `request_certificate`: Set to `gcp` to request a GCP Certificate Manager certificate or `selfsigned` for testing.

### Run Terraform

Activate your GCP credentials in your shell environment.
Terraform must be applied in several stages.

Initialise Terraform providers and modules:

```sh
terraform init
```

Deploy the GKE cluster control plane, Cloud DNS Private Zone, Filestore, and HTTPS certificate:

```sh
terraform apply -var-file=overrides.tfvars -var deployment_stage=0
```

Deploy GKE compute nodes and Cilium:

```sh
terraform apply -var-file=overrides.tfvars -var deployment_stage=1
```

Deploy ArgoCD and prerequisites:

```sh
terraform apply -var-file=overrides.tfvars -var deployment_stage=2
```

Deploy K8TRE:

```sh
terraform apply -var-file=overrides.tfvars -var deployment_stage=3
```

### Kubernetes access

`terraform apply` should display the command (`gcloud container clusters get-credentials ...`) to create a kubeconfig file for the `k8tre-dev` and `k8tre-argocd-dev` clusters.

### Linting

When making changes to this repository run:

```sh
terraform validate
prek run -a
```

prek (or pre-commit) will run some autoformatters, and TFlint.

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

By default this will deploy two GKE clusters in a single zone (`var.zone`, configurable via `number_availability_zones`):

- `k8tre-dev-argocd` is where ArgoCD will run
- `k8tre-dev` is where K8TRE will be deployed

The clusters use GKE native capabilities:

- **GKE Dataplane V2 (`ADVANCED_DATAPATH`):** Native managed Cilium CNI with eBPF kube-proxy replacement, `CiliumNetworkPolicy` enforcement, and Hubble Relay observability.
- **GKE Gateway API (`CHANNEL_STANDARD`):** Native Gateway API CRDs and controller.
- **Cloud DNS for GKE (`CLOUD_DNS`):** Native cluster DNS resolution.
- **GKE Workload Identity:** Allows ArgoCD running in `k8tre-dev-argocd` to have admin access to `k8tre-dev`, and grants External DNS, External Secrets, and GCS Fuse access to GCP APIs.

### Shared RWX Storage (`rwx-default`)

Two options are supported for the `rwx-default` `ReadWriteMany` StorageClass:

1. **In-cluster NFS provisioner (default, `enable_filestore_rwx = false`):** Deploys `nfs-server-provisioner` backed by a CMEK-encrypted `pd-balanced` GCE Persistent Disk (`rwx_nfs_disk_size_gb`, default 100 GB). Suitable for development and small production deployments at minimal cost.
2. **GCP Filestore CSI dynamic provisioning (`enable_filestore_rwx = true`):** Uses `filestore.csi.storage.gcp.io` with Filestore Multishares (`rwx_filestore_tier = "enterprise"` by default) for large-scale production deployments.

### Configuration

Edit [`provider.tf`](provider.tf).
You must modify `terraform.backend.gcs` `bucket` to match the one in `bootstrap/backend.tf`.

You can install K8TRE GCP with no changes, but you will most likely want to set some variables.
Either modify [`variables.tf`](variables.tf), or copy [`overrides.tfvars-example`](overrides.tfvars-example) to `overrides.tfvars` and edit.

Particularly important variables include

- `project_id`: Your GCP Project ID
- `region` and `zone`: GCP region and zone, e.g. `europe-west2` and `europe-west2-a`
- `number_availability_zones`: Defaults to `1` (single-zone GKE cluster) to avoid cross-zone `ReadWriteOnce` Persistent Disk affinity issues and reduce GKE control plane and node costs.
- `dns_domain`: The domain for K8TRE, e.g. `k8tre.example.org`
- `request_certificate`: Set to `gcp` to request a GCP Certificate Manager certificate (with DNS authorization records output in `dns_validation_records`) or `selfsigned` for testing.
- `enable_filestore_rwx`: Set to `true` only for large-scale production deployments requiring managed GCP Filestore.

### Run Terraform

Activate your GCP credentials in your shell environment.
Terraform must be applied in several stages.

Initialise Terraform providers and modules:

```sh
terraform init
```

Deploy the GKE cluster control plane (with native Cilium Dataplane V2 and Gateway API), Cloud DNS Private Zone, KMS keys, and HTTPS certificate:

```sh
terraform apply -var-file=overrides.tfvars -var deployment_stage=0
```

If you set `request_certificate = "gcp"` then create the DNS validation records shown in the `dns_validation_records` output.

Deploy GKE compute node pools:

```sh
terraform apply -var-file=overrides.tfvars -var deployment_stage=1
```

Deploy storage classes (`rwo-default` and `rwx-default`), ArgoCD, and cluster registration:

```sh
terraform apply -var-file=overrides.tfvars -var deployment_stage=2
```

Deploy K8TRE:

```sh
terraform apply -var-file=overrides.tfvars -var deployment_stage=3
```

### Kubernetes & ArgoCD access

`terraform apply` displays the `gcloud container clusters get-credentials ...` commands to create kubeconfig files for the `k8tre-dev` and `k8tre-dev-argocd` clusters.

For convenience you can run [`./argocd-portforward.sh`](argocd-portforward.sh) to start a port-forward to the ArgoCD web interface on `http://localhost:8080`.

### Linting

When making changes to this repository run:

```sh
terraform validate
prek run -a
```

prek (or pre-commit) will run some autoformatters, and TFlint.

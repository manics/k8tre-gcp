# GCP GKE Module Variables

variable "deployment_stage" {
  type        = number
  description = "Multi-stage deployment step, run with 0 the first time, then with 1."
}

variable "project_id" {
  type        = string
  description = "GCP Project ID"
  default     = "k8tre-dev-project"
}

variable "region" {
  type        = string
  description = "GCP Region"
  default     = "europe-west2"
}

variable "zone" {
  type        = string
  description = "Primary GCP Zone (used when number_azs = 1)"
  default     = "europe-west2-a"
}

variable "number_azs" {
  type        = number
  default     = 1
  description = "Number of availability zones to use (1 for zonal cluster, 2 or 3 for regional cluster)"
  validation {
    condition     = var.number_azs >= 1 && var.number_azs <= 3
    error_message = "number_azs must be between 1 and 3"
  }
}

variable "cluster_name" {
  type        = string
  description = "GKE cluster name"
}

variable "network" {
  type        = string
  description = "VPC network name or self link"
}

variable "subnetwork" {
  type        = string
  description = "VPC subnetwork name or self link"
}

variable "ip_range_pods" {
  type        = string
  description = "Secondary IP range name for GKE pods"
  default     = "gke-pods"
}

variable "ip_range_services" {
  type        = string
  description = "Secondary IP range name for GKE services"
  default     = "gke-services"
}

variable "master_ipv4_cidr_block" {
  type        = string
  description = "The /28 IP range in CIDR notation to use for the hosted GKE control plane network"
  default     = "172.16.0.0/28"
}

variable "k8s_version" {
  type        = string
  description = "Kubernetes cluster minimum version"
  default     = "1.32"
}

variable "k8s_api_cidrs" {
  type        = list(string)
  default     = ["127.0.0.1/8"]
  description = "CIDRs that have access to the K8s API master authorized networks"
}

variable "instance_type_wg1" {
  type        = string
  default     = "e2-standard-4"
  description = "Worker group 1 GKE node machine type"
}

variable "root_volume_size" {
  type        = number
  default     = 100
  description = "Root disk size in GB"
}

variable "wg1_size" {
  type        = number
  default     = 2
  description = "Worker group 1 initial desired number of nodes per zone"
}

variable "wg1_max_size" {
  type        = number
  default     = 2
  description = "Worker group 1 maximum number of nodes per zone"
}

variable "autoupdate_nodes" {
  type        = bool
  default     = true
  description = "Whether to enable GKE node auto-upgrade"
}

variable "kms_key_name" {
  type        = string
  default     = null
  description = "Optional Cloud KMS crypto key ID for GKE application-layer Secrets encryption"
}

variable "create_pod_identities" {
  type        = bool
  default     = false
  description = "Enable Workload Identity bindings for additional service accounts"
}

variable "hosted_zone_ids" {
  type        = list(string)
  default     = []
  description = "Cloud DNS hosted zone IDs for External DNS, set to empty to disable"
}

variable "gcs_mountable_buckets" {
  type        = list(string)
  default     = []
  description = "List of GCS bucket names that may be mounted into pods via GCS Fuse"
}

variable "gcs_mountable_bucket_keys" {
  type        = list(string)
  default     = []
  description = "List of KMS key IDs required to decrypt data mounted into pods"
}

variable "argocd_create_role" {
  type        = bool
  description = "Whether to create ArgoCD Workload Identity roles"
  default     = false
}

variable "argocd_namespace" {
  type        = string
  description = "Namespace of ArgoCD, used to create Workload Identity"
  default     = "argocd"
}

variable "argocd_target_gke_access_sa" {
  type        = string
  description = "Target cluster GKE admin Service Account email that ArgoCD can impersonate"
  default     = ""
}

variable "argocd_serviceaccount_names" {
  type        = list(string)
  description = "Names of the ArgoCD service accounts"
  default     = ["argocd-application-controller", "argocd-applicationset-controller", "argocd-server"]
}

variable "github_oidc_rolename" {
  type        = string
  description = "Name of GitHub OIDC workload identity pool provider, set to null to disable"
  default     = null
}

variable "github_oidc_role_sub" {
  type        = list(string)
  description = "List of GitHub subject claims (e.g. repo:k8tre/k8tre:ref:refs/heads/main) allowed to use OIDC pool"
  default     = []
}

variable "additional_admin_principals" {
  type        = map(string)
  description = "Additional admin IAM principals (e.g. serviceAccount:... or user:...)"
  default     = {}
}

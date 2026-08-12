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

variable "k8s_version" {
  type        = string
  description = "Kubernetes cluster version"
  default     = "1.30"
}

variable "k8s_api_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
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
  description = "Worker group 1 initial desired number of nodes"
}

variable "wg1_max_size" {
  type        = number
  default     = 2
  description = "Worker group 1 maximum number of nodes"
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

variable "s3_mountable_bucket_arns" {
  type        = list(string)
  default     = []
  description = "List of GCS bucket names that may be mounted into pods via GCS Fuse"
}

# tflint-ignore: terraform_unused_declarations
variable "s3_mountable_bucket_keys" {
  type        = list(string)
  default     = []
  description = "List of KMS key names required to decrypt data mounted into pods"
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

# tflint-ignore: terraform_unused_declarations
variable "argocd_assume_eks_access_role" {
  type        = string
  description = "Role ARN or Service Account that ArgoCD should assume"
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

# tflint-ignore: terraform_unused_declarations
variable "github_oidc_role_sub" {
  type        = list(string)
  description = "List of GitHub repos/refs allowed to use OIDC role"
  default     = []
}

# tflint-ignore: terraform_unused_declarations
variable "additional_admin_principals" {
  type        = map(string)
  description = "Additional admin IAM principals"
  default     = {}
}


variable "gateway_api_version" {
  type        = string
  description = "Gateway API CRD version"
  default     = "1.4.1"
}

variable "cilium_version" {
  type        = string
  description = "Cilium version"
  default     = "1.19.2"
}


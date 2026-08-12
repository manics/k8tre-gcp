variable "name" {
  type        = string
  description = "Deployment name, used to prefix some resources"
}

variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

# tflint-ignore: terraform_unused_declarations
variable "region" {
  type        = string
  description = "GCP region"
}

variable "zone" {
  type        = string
  description = "GCP zone"
}

variable "network" {
  type        = string
  description = "VPC network name"
}

variable "public_subnet" {
  type        = string
  description = "Public subnetwork name"
}

variable "outbound_proxy_cidrs" {
  type        = list(string)
  description = "Route these CIDRs to the transparent proxy"
  default     = ["0.0.0.0/0"]
}

variable "gcs_config_bucket" {
  type        = string
  description = "An existing GCS bucket name used for storing config files"
}

variable "allowed_domains" {
  type        = list(string)
  default     = []
  description = "Allowed domains (HTTP and HTTPS)"
}

# tflint-ignore: terraform_unused_declarations
variable "log_group_retention_days" {
  type        = number
  default     = 365
  description = "Retention period for logs"
}

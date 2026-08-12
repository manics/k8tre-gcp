variable "name" {
  type        = string
  description = "Name used for resources"
}

variable "network" {
  type        = string
  description = "VPC network name or self link"
}

variable "location" {
  type        = string
  description = "GCP zone or region for Filestore instance"
  default     = "europe-west2-a"
}

variable "tier" {
  type        = string
  description = "Filestore tier (BASIC_HDD, BASIC_SSD, HIGH_SCALE_SSD, ENTERPRISE)"
  default     = "BASIC_HDD"
}

variable "kms_key_name" {
  type        = string
  description = "KMS encryption key name"
  default     = null
}


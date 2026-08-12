variable "domain_name" {
  type        = string
  description = "Domain for the certificate, can be a wildcard"
}

variable "subject_alternative_names" {
  type        = list(string)
  default     = []
  description = "Subject alternative names (SANs), ignored for self-signed certificate"
}

variable "organisation" {
  type        = string
  default     = "TREvolution"
  description = "Organisation, only used for self signed certificate"
}

variable "request_gcp_certificate" {
  type        = bool
  default     = true
  description = <<-EOT
  Request a GCP Certificate Manager certificate or self-signed certificate.
  Set to false to generate a self-signed certificate for testing.
  EOT
}


terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  required_version = ">= 1.15.0"
}

locals {
  request_gcp_certificate = var.request_gcp_certificate ? 1 : 0
  create_self_signed_cert = var.request_gcp_certificate ? 0 : 1
}


######################################################################
# Self signed certificate

resource "tls_private_key" "self_signed_cert_key" {
  count = local.create_self_signed_cert

  algorithm = "RSA"
}

resource "tls_self_signed_cert" "self_signed_cert" {
  count = local.create_self_signed_cert

  private_key_pem = tls_private_key.self_signed_cert_key[0].private_key_pem

  # One month, renew with 10 days to go
  early_renewal_hours   = 240
  validity_period_hours = 750

  subject {
    common_name  = var.domain_name
    organization = var.organisation
  }

  allowed_uses = ["key_encipherment", "digital_signature", "server_auth"]
}

resource "google_certificate_manager_certificate" "self_signed_cert" {
  count       = local.create_self_signed_cert
  name        = replace(replace(var.domain_name, "*.", "wildcard-"), ".", "-")
  description = "Self signed certificate for ${var.domain_name}"
  scope       = "DEFAULT"

  self_managed {
    pem_certificate = tls_self_signed_cert.self_signed_cert[0].cert_pem
    pem_private_key = tls_private_key.self_signed_cert_key[0].private_key_pem
  }
}


######################################################################
# Request GCP Managed Certificate

resource "google_certificate_manager_certificate" "certificate" {
  count       = local.request_gcp_certificate
  name        = replace(replace(var.domain_name, "*.", "wildcard-"), ".", "-")
  description = "Managed certificate for ${var.domain_name}"
  scope       = "DEFAULT"

  managed {
    domains = concat([var.domain_name], var.subject_alternative_names)
  }
}


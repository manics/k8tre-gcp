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

  cert_name   = replace(replace(var.domain_name, "*.", "wildcard-"), ".", "-")
  all_domains = distinct(concat([var.domain_name], var.subject_alternative_names))

  # A single DnsAuthorization for "example.org" covers both "example.org" and "*.example.org"
  auth_domains = toset(var.request_gcp_certificate ? [
    for domain in local.all_domains : trimprefix(domain, "*.")
  ] : [])

  certificate_id = var.request_gcp_certificate ? google_certificate_manager_certificate.certificate[0].id : google_certificate_manager_certificate.self_signed_cert[0].id
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

  dns_names = local.all_domains

  allowed_uses = ["key_encipherment", "digital_signature", "server_auth"]
}

resource "google_certificate_manager_certificate" "self_signed_cert" {
  count       = local.create_self_signed_cert
  name        = local.cert_name
  description = "Self signed certificate for ${var.domain_name}"
  scope       = "DEFAULT"

  self_managed {
    pem_certificate = tls_self_signed_cert.self_signed_cert[0].cert_pem
    pem_private_key = tls_private_key.self_signed_cert_key[0].private_key_pem
  }
}


######################################################################
# Request GCP Managed Certificate (with DNS Authorization for wildcards)

resource "google_certificate_manager_dns_authorization" "auth" {
  for_each    = local.auth_domains
  name        = "${replace(each.value, ".", "-")}-dns-auth"
  description = "DNS authorization for ${each.value}"
  domain      = each.value
}

resource "google_certificate_manager_certificate" "certificate" {
  count       = local.request_gcp_certificate
  name        = local.cert_name
  description = "Managed certificate for ${var.domain_name}"
  scope       = "DEFAULT"

  managed {
    domains            = local.all_domains
    dns_authorizations = [for auth in google_certificate_manager_dns_authorization.auth : auth.id]
  }
}


######################################################################
# Certificate Map for GKE Gateway / GCP Load Balancers

resource "google_certificate_manager_certificate_map" "map" {
  name        = "${local.cert_name}-map"
  description = "Certificate map for ${var.domain_name}"
}

resource "google_certificate_manager_certificate_map_entry" "entry" {
  for_each = toset(local.all_domains)

  name         = replace(replace(each.value, "*.", "wildcard-"), ".", "-")
  description  = "Certificate map entry for ${each.value}"
  map          = google_certificate_manager_certificate_map.map.name
  certificates = [local.certificate_id]
  hostname     = each.value
}

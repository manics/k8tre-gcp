terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.15.0"
}

locals {
  sanitised_zone_name = replace(replace(var.name, ".", "-"), "/-+$/", "")
}

######################################################################
# Public zone
######################################################################

resource "google_dns_managed_zone" "public-zone" {
  count       = var.create_public_zone ? 1 : 0
  name        = "public-${local.sanitised_zone_name}"
  dns_name    = "${var.name}."
  description = "Public DNS zone for ${var.name}"
  visibility  = "public"
}

resource "google_dns_record_set" "public-record" {
  for_each = var.create_public_zone ? var.public-records : {}

  managed_zone = google_dns_managed_zone.public-zone[0].name
  name         = format("%s.%s.", split(" ", each.key)[0], var.name)
  type         = split(" ", each.key)[1]
  ttl          = 300
  rrdatas      = each.value
}

######################################################################
# Private zone & Cloud DNS Policy
######################################################################

resource "google_dns_managed_zone" "private-zone" {
  name        = "private-${local.sanitised_zone_name}"
  dns_name    = "${var.name}."
  description = "Private DNS zone for ${var.name}"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = var.vpc
    }
  }
}

resource "google_dns_policy" "vpc-dns-policy" {
  name                      = "dns-policy-${local.sanitised_zone_name}"
  description               = "Cloud DNS policy for ${var.name} VPC"
  enable_inbound_forwarding = var.enable_inbound_forwarding
  enable_logging            = var.enable_logging

  networks {
    network_url = var.vpc
  }
}

resource "google_dns_record_set" "private-record" {
  for_each = var.private-records

  managed_zone = google_dns_managed_zone.private-zone.name
  name         = format("%s.%s.", split(" ", each.key)[0], var.name)
  type         = split(" ", each.key)[1]
  ttl          = 300
  rrdatas      = each.value
}

resource "google_dns_record_set" "static-record" {
  for_each = zipmap([for e in var.static : format("%s:%s:%s", e[0], e[1], e[2])], var.static)

  managed_zone = google_dns_managed_zone.private-zone.name
  name         = format("%s.%s.", each.value[0], var.name)
  type         = each.value[1]
  ttl          = var.static-ttl
  rrdatas      = [each.value[2]]
}

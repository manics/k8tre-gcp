output "private-zone-id" {
  description = "Private Cloud DNS managed zone ID"
  value       = google_dns_managed_zone.private-zone.id
}

output "private-zone-name" {
  description = "Private Cloud DNS managed zone name"
  value       = google_dns_managed_zone.private-zone.name
}

output "public-zone-id" {
  description = "Public Cloud DNS managed zone ID if enabled"
  value       = var.create_public_zone ? google_dns_managed_zone.public-zone[0].id : null
}

output "public-zone-name" {
  description = "Public Cloud DNS managed zone name if enabled"
  value       = var.create_public_zone ? google_dns_managed_zone.public-zone[0].name : null
}

output "public-primary-nameserver" {
  description = "Primary nameserver of the public Cloud DNS zone"
  value       = var.create_public_zone ? google_dns_managed_zone.public-zone[0].name_servers[0] : null
}

output "public-nameservers" {
  description = "Nameservers of the public Cloud DNS zone"
  value       = var.create_public_zone ? google_dns_managed_zone.public-zone[0].name_servers : []
}

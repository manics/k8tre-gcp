output "private-zone-id" {
  value = google_dns_managed_zone.private-zone.id
}

output "public-zone-id" {
  value = var.create_public_zone ? google_dns_managed_zone.public-zone[0].id : null
}

output "public-primary-nameserver" {
  value = var.create_public_zone ? google_dns_managed_zone.public-zone[0].name_servers[0] : null
}

output "public-nameservers" {
  value = var.create_public_zone ? google_dns_managed_zone.public-zone[0].name_servers : []
}


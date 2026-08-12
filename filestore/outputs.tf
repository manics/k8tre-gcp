output "file_system_id" {
  description = "Filestore instance ID"
  value       = google_filestore_instance.instance.id
}

output "file_share_name" {
  description = "Filestore file share name"
  value       = google_filestore_instance.instance.file_shares[0].name
}

output "ip_addresses" {
  description = "Filestore IP addresses"
  value       = google_filestore_instance.instance.networks[0].ip_addresses
}


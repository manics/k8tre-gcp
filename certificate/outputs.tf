output "dns_validation_records" {
  description = "DNS validation records to be created for GCP Certificate Manager DNS authorization"
  value = {
    for domain, auth in google_certificate_manager_dns_authorization.auth :
    domain => {
      name   = auth.dns_resource_record[0].name
      record = auth.dns_resource_record[0].data
      type   = auth.dns_resource_record[0].type
    }
  }
}

output "certificate_id" {
  description = "GCP Certificate Manager certificate ID"
  value       = local.certificate_id
}

output "certificate_map_name" {
  description = "GCP Certificate Manager certificate map name (for GKE Gateway networking.gke.io/certmap annotation)"
  value       = google_certificate_manager_certificate_map.map.name
}

output "dns_validation_records" {
  description = "DNS validation records to be created for certificate"
  value       = {}
}

output "certificate_id" {
  description = "GCP Certificate Manager certificate ID"
  value       = var.request_gcp_certificate ? (length(google_certificate_manager_certificate.certificate) > 0 ? google_certificate_manager_certificate.certificate[0].id : null) : (length(google_certificate_manager_certificate.self_signed_cert) > 0 ? google_certificate_manager_certificate.self_signed_cert[0].id : null)
}


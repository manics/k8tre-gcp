output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = google_container_cluster.primary.name
}

output "cluster_location" {
  description = "GKE cluster location (zone or region)"
  value       = google_container_cluster.primary.location
}

output "cluster_endpoint" {
  description = "The public endpoint for the GKE Kubernetes API"
  value       = google_container_cluster.primary.endpoint
}

output "cluster_private_endpoint" {
  description = "The internal VPC endpoint for the GKE Kubernetes API"
  value       = google_container_cluster.primary.private_cluster_config[0].private_endpoint
}

output "cluster_ca_certificate" {
  description = "The GKE certificate authority data in base64"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
}

output "gke_token" {
  description = "The GCP client access token for GKE API"
  value       = data.google_client_config.default.access_token
  sensitive   = true
}

output "gke_access_service_account" {
  description = "Service account email that has admin access to this GKE cluster"
  value       = google_service_account.gke_access.email
}

output "argocd_service_account_email" {
  description = "ArgoCD Workload Identity Google Service Account email if created"
  value       = var.argocd_create_role ? google_service_account.argocd_sa[0].email : null
}

output "external_dns_service_account_email" {
  description = "External DNS Workload Identity Google Service Account email if created"
  value       = local.create_external_dns_pod_identity > 0 ? google_service_account.external_dns[0].email : null
}

output "external_secrets_service_account_email" {
  description = "External Secrets Workload Identity Google Service Account email if created"
  value       = local.create_pod_identities > 0 ? google_service_account.external_secrets[0].email : null
}

output "gcs_fuse_service_account_email" {
  description = "GCS Fuse Workload Identity Google Service Account email if created"
  value       = local.create_gcs_csi_pod_identity > 0 ? google_service_account.gcs_fuse[0].email : null
}

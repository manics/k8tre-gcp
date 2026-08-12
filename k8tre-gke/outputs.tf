output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "The endpoint for the GKE Kubernetes API"
  value       = google_container_cluster.primary.endpoint
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

output "eks_access_role" {
  description = "Service account email that can access this GKE cluster"
  value       = google_service_account.gke_access.email
}


output "kubeconfig_command_k8tre-dev" {
  description = "Create kubeconfig for k8tre-dev"
  value       = "gcloud container clusters get-credentials ${module.k8tre-gke.cluster_name} --location ${module.k8tre-gke.cluster_location} --project ${var.project_id}"
}

output "kubeconfig_command_k8tre-argocd-dev" {
  description = "Create kubeconfig for k8tre-argocd-dev"
  value       = "gcloud container clusters get-credentials ${module.k8tre-argocd-gke.cluster_name} --location ${module.k8tre-argocd-gke.cluster_location} --project ${var.project_id}"
}

output "name" {
  description = "Name used for most resources"
  value       = var.name
}

output "vpc_name" {
  description = "VPC Network Name"
  value       = google_compute_network.vpc.name
}

output "k8tre_cluster_name" {
  description = "K8TRE dev cluster name"
  value       = module.k8tre-gke.cluster_name
}

output "k8tre_argocd_cluster_name" {
  description = "K8TRE dev ArgoCD cluster name"
  value       = module.k8tre-argocd-gke.cluster_name
}

output "k8tre_gke_access_service_account" {
  description = "K8TRE GKE deployment service account email"
  value       = module.k8tre-gke.gke_access_service_account
}

output "external_dns_service_account_email" {
  description = "External DNS Workload Identity Google Service Account email"
  value       = module.k8tre-gke.external_dns_service_account_email
}

output "external_secrets_service_account_email" {
  description = "External Secrets Workload Identity Google Service Account email"
  value       = module.k8tre-gke.external_secrets_service_account_email
}

output "gcs_fuse_service_account_email" {
  description = "GCS Fuse Workload Identity Google Service Account email"
  value       = module.k8tre-gke.gcs_fuse_service_account_email
}

output "dns_validation_records" {
  description = "DNS validation records to be created for GCP Certificate Manager certificate"
  value       = module.certificate[*].dns_validation_records
}

output "certificate_map_name" {
  description = "GCP Certificate Manager certificate map name"
  value       = module.certificate[*].certificate_map_name
}

output "proxy_instance_name" {
  description = "Transparent proxy Compute Engine VM instance name if enabled"
  value       = module.transparent-proxy[*].proxy_instance_name
}

output "gcs_studydata_bucket_name" {
  description = "Name of the GCS studydata bucket"
  value       = google_storage_bucket.studydata.name
}

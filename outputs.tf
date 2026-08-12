output "kubeconfig_command_k8tre-dev" {
  description = "Create kubeconfig for k8tre-dev"
  value       = "gcloud container clusters get-credentials ${module.k8tre-gke.cluster_name} --region ${var.region} --project ${var.project_id}"
}

output "kubeconfig_command_k8tre-argocd-dev" {
  description = "Create kubeconfig for k8tre-argocd-dev"
  value       = "gcloud container clusters get-credentials ${module.k8tre-argocd-gke.cluster_name} --region ${var.region} --project ${var.project_id}"
}

output "name" {
  description = "Name used for most resources"
  value       = var.name
}

output "filestore_id" {
  description = "Filestore instance ID"
  value       = module.filestore.file_system_id
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

output "k8tre_gke_access_role" {
  description = "K8TRE GKE deployment service account email"
  value       = module.k8tre-gke.eks_access_role
}

output "dns_validation_records" {
  description = "DNS validation records"
  value       = module.certificate[*].dns_validation_records
}

output "proxy_instance_name" {
  description = "Transparent proxy Compute Engine VM instance name if enabled"
  value       = module.transparent-proxy[*].proxy_instance_name
}

output "gcs_studydata_bucket_name" {
  description = "Name of the GCS studydata bucket"
  value       = google_storage_bucket.studydata.name
}

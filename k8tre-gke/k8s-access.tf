# Roles and Workload Identity configuration for GKE access

# GitHub OIDC Workload Identity Pool & Provider
resource "google_iam_workload_identity_pool" "github_pool" {
  count                     = var.github_oidc_rolename == null ? 0 : 1
  workload_identity_pool_id = "${var.cluster_name}-github-pool"
  display_name              = "GitHub Workload Identity Pool for ${var.cluster_name}"
  description               = "Identity pool for GitHub Actions OIDC federation"
  project                   = var.project_id
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  count                              = var.github_oidc_rolename == null ? 0 : 1
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Actions Provider"
  project                            = var.project_id

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Service account for cluster admin access
resource "google_service_account" "gke_access" {
  account_id   = "${var.cluster_name}-gke-admin"
  display_name = "Service Account for ${var.cluster_name} administration"
  project      = var.project_id
}

resource "google_project_iam_member" "gke_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.gke_access.email}"
}

# ArgoCD Workload Identity bindings
resource "google_service_account" "argocd_sa" {
  count        = var.argocd_create_role ? 1 : 0
  account_id   = "${var.cluster_name}-argocd-sa"
  display_name = "ArgoCD Workload Identity SA for ${var.cluster_name}"
  project      = var.project_id
}

resource "google_service_account_iam_binding" "argocd_workload_identity" {
  for_each           = var.argocd_create_role ? toset(var.argocd_serviceaccount_names) : toset([])
  service_account_id = google_service_account.argocd_sa[0].name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.argocd_namespace}/${each.value}]"
  ]
}


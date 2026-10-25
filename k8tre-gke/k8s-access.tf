# Roles and Workload Identity configuration for GKE nodes and cluster access

######################################################################
# Dedicated Least-Privilege Node Service Account

resource "google_service_account" "node_sa" {
  account_id   = "${var.cluster_name}-node-sa"
  display_name = "GKE Node Service Account for ${var.cluster_name}"
  project      = var.project_id
}

resource "google_project_iam_member" "node_sa_default" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.node_sa.email}"
}


######################################################################
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

  attribute_condition = length(var.github_oidc_role_sub) > 0 ? join(" || ", [
    for sub in var.github_oidc_role_sub : "assertion.sub == '${sub}'"
  ]) : "assertion.repository != ''"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github_oidc_workload_identity" {
  count              = var.github_oidc_rolename == null ? 0 : 1
  service_account_id = google_service_account.gke_access.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool[0].name}/*"
}


######################################################################
# Service account and IAM bindings for cluster admin access

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

resource "google_project_iam_member" "additional_admins" {
  for_each = var.additional_admin_principals
  project  = var.project_id
  role     = "roles/container.admin"
  member   = each.value
}


######################################################################
# ArgoCD Workload Identity bindings

resource "google_service_account" "argocd_sa" {
  count        = var.argocd_create_role ? 1 : 0
  account_id   = "${var.cluster_name}-sa"
  display_name = "ArgoCD Workload Identity SA for ${var.cluster_name}"
  project      = var.project_id
}

resource "google_project_iam_member" "argocd_gke_admin" {
  count   = var.argocd_create_role ? 1 : 0
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.argocd_sa[0].email}"
}

resource "google_service_account_iam_member" "argocd_impersonate_target" {
  count              = (var.argocd_create_role && length(var.argocd_target_gke_access_sa) > 0) ? 1 : 0
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.argocd_target_gke_access_sa}"
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.argocd_sa[0].email}"
}

resource "google_service_account_iam_binding" "argocd_workload_identity" {
  count              = var.argocd_create_role ? 1 : 0
  service_account_id = google_service_account.argocd_sa[0].name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    for sa in var.argocd_serviceaccount_names :
    "serviceAccount:${var.project_id}.svc.id.goog[${var.argocd_namespace}/${sa}]"
  ]
}

# GCP Workload Identity bindings for Kubernetes Service Accounts

# External DNS Workload Identity
resource "google_service_account" "external_dns" {
  count        = local.create_external_dns_pod_identity
  account_id   = "${var.cluster_name}-extdns"
  display_name = "External DNS SA for ${var.cluster_name}"
}

resource "google_project_iam_member" "external_dns" {
  count   = local.create_external_dns_pod_identity
  project = data.google_project.current.name
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.external_dns[0].email}"
}

resource "google_service_account_iam_binding" "external_dns_workload_identity" {
  count              = local.create_external_dns_pod_identity
  service_account_id = google_service_account.external_dns[0].name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${data.google_project.current.project_id}.svc.id.goog[externaldns/externaldns-sa]"
  ]
  depends_on = [google_container_cluster.primary]
}

# External Secrets Workload Identity
resource "google_service_account" "external_secrets" {
  count        = local.create_pod_identities
  account_id   = "${var.cluster_name}-extsec"
  display_name = "External Secrets SA for ${var.cluster_name}"
}

resource "google_project_iam_member" "external_secrets" {
  count   = local.create_pod_identities
  project = data.google_project.current.name
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.external_secrets[0].email}"
}

resource "google_service_account_iam_binding" "external_secrets_workload_identity" {
  count              = local.create_pod_identities
  service_account_id = google_service_account.external_secrets[0].name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${data.google_project.current.project_id}.svc.id.goog[external-secrets/external-secrets]"
  ]
  depends_on = [google_container_cluster.primary]
}

# GKE Storage Workload Identity bindings for GCS Fuse and GCS access

resource "google_service_account" "gcs_fuse" {
  count        = local.create_s3_csi_pod_identity
  account_id   = "${var.cluster_name}-gcs-fuse"
  display_name = "GCS Fuse CSI Service Account for ${var.cluster_name}"
  project      = var.project_id
}

resource "google_storage_bucket_iam_member" "gcs_fuse_reader" {
  count  = local.create_s3_csi_pod_identity > 0 && length(var.s3_mountable_bucket_arns) > 0 ? length(var.s3_mountable_bucket_arns) : 0
  bucket = var.s3_mountable_bucket_arns[count.index]
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.gcs_fuse[0].email}"
}

resource "google_service_account_iam_binding" "gcs_fuse_workload_identity" {
  count              = local.create_s3_csi_pod_identity
  service_account_id = google_service_account.gcs_fuse[0].name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[kube-system/gcs-fuse-csi-driver-sa]"
  ]
}


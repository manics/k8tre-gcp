terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0.0"
    }
  }

  required_version = ">= 1.15.0"
}

resource "google_storage_bucket_object" "allowlist" {
  name    = "${var.name}-transparent-proxy/allowlist.txt"
  bucket  = var.gcs_config_bucket
  content = format("%s\n", join("\n", var.allowed_domains))
}

resource "google_service_account" "transparent_proxy" {
  account_id   = "${var.name}-proxy-sa"
  display_name = "Transparent Proxy Service Account"
  project      = var.project_id
}

resource "google_storage_bucket_iam_member" "proxy_gcs_read" {
  bucket = var.gcs_config_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.transparent_proxy.email}"
}

resource "google_project_iam_member" "proxy_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.transparent_proxy.email}"
}

resource "google_project_iam_member" "proxy_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.transparent_proxy.email}"
}

resource "google_compute_firewall" "allow_proxy_ingress" {
  name    = "${var.name}-allow-proxy-ingress"
  network = var.network
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "3128", "3129"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["transparent-proxy"]
}

resource "google_compute_instance" "transparent_proxy" {
  name         = "${var.name}-transparent-proxy"
  machine_type = "e2-medium"
  zone         = var.zone
  project      = var.project_id

  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = 20
    }
  }

  network_interface {
    subnetwork = var.public_subnet
    access_config {
      // Ephemeral public IP for outbound internet access
    }
  }

  service_account {
    email  = google_service_account.transparent_proxy.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = templatefile("${path.module}/userdata.sh", {
    gcs_config_bucket = var.gcs_config_bucket
    name              = var.name
  })

  tags = ["transparent-proxy", "http-server", "https-server"]

  lifecycle {
    ignore_changes = [boot_disk[0].initialize_params[0].image]
  }
}

resource "google_compute_route" "private_subnet_to_proxy" {
  count             = length(var.outbound_proxy_cidrs)
  name              = "${var.name}-private-to-proxy-${count.index}"
  dest_range        = var.outbound_proxy_cidrs[count.index]
  network           = var.network
  next_hop_instance = google_compute_instance.transparent_proxy.self_link
  priority          = 900
  project           = var.project_id

  tags = ["gke-node"]
}

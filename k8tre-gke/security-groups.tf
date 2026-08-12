# GCP Firewall Rules for GKE Cluster

resource "google_compute_firewall" "allow_internal" {
  name    = "${var.cluster_name}-allow-internal"
  network = var.network
  project = var.project_id

  description = "Allow internal traffic between worker nodes"

  allow {
    protocol = "all"
  }

  source_ranges = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16"
  ]
}

resource "google_compute_firewall" "allow_mgmt" {
  name    = "${var.cluster_name}-allow-mgmt"
  network = var.network
  project = var.project_id

  description = "Worker nodes management access"

  allow {
    protocol = "tcp"
    ports    = ["22", "443"]
  }

  source_ranges = [
    "10.0.0.0/8"
  ]
}


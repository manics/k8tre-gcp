# GCP Firewall Rules for GKE Cluster

resource "google_compute_firewall" "allow_internal" {
  name    = "${var.cluster_name}-allow-internal"
  network = var.network
  project = var.project_id

  description = "Allow internal traffic between worker nodes and pods"

  allow {
    protocol = "all"
  }

  source_ranges = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16",
  ]

  target_tags = ["${var.cluster_name}-node"]
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.cluster_name}-allow-iap-ssh"
  network = var.network
  project = var.project_id

  description = "Allow SSH access to worker nodes via Google Cloud IAP TCP forwarding"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [
    "35.235.240.0/20",
  ]

  target_tags = ["${var.cluster_name}-node"]
}

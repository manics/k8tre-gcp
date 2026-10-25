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
  name         = "${var.name}-transparent-proxy/allowlist.txt"
  bucket       = var.gcs_config_bucket
  content      = format("%s\n", join("\n", var.allowed_domains))
  content_type = "text/plain"
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
  name        = "${var.name}-allow-proxy-ingress"
  network     = var.network
  project     = var.project_id
  description = "Allow inbound HTTP/HTTPS traffic from internal VPC/Pod CIDRs to transparent proxy"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = var.allowed_source_ranges
  target_tags   = ["transparent-proxy"]
}

resource "google_compute_firewall" "allow_proxy_iap_ssh" {
  name        = "${var.name}-allow-proxy-iap-ssh"
  network     = var.network
  project     = var.project_id
  description = "Allow SSH access to transparent proxy via Google Cloud IAP TCP forwarding"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Google Cloud Identity-Aware Proxy (IAP) TCP forwarding IP range
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["transparent-proxy"]
}

resource "google_compute_instance" "transparent_proxy" {
  name         = "${var.name}-transparent-proxy"
  machine_type = "e2-medium"
  zone         = var.zone
  project      = var.project_id

  # Allow packet interception / forwarding as a next-hop instance
  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = 20
      type  = "pd-balanced"
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

  tags = ["transparent-proxy"]

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

######################################################################
# Cloud Logging & Monitoring Alerting for Blocked Requests

resource "google_logging_project_bucket_config" "transparent_proxy" {
  project        = var.project_id
  location       = var.region
  bucket_id      = "${var.name}-transparent-proxy"
  retention_days = var.log_group_retention_days
  description    = "Log bucket for ${var.name} transparent proxy access and blocked logs"
}

resource "google_logging_metric" "transparent_proxy_denied" {
  name        = "${var.name}/transparent-proxy-denied"
  project     = var.project_id
  description = "Count of HTTP (TCP_DENIED) and HTTPS (NONE_NONE) requests blocked by the Squid transparent proxy"

  # Matches blocked requests logged to squid_blocked by Google Cloud Ops Agent:
  # - HTTP: TCP_DENIED/403
  # - HTTPS: NONE_NONE/000 (TLS handshake terminated on SNI mismatch)
  filter = <<-EOT
    resource.type="gce_instance"
    logName="projects/${var.project_id}/logs/squid_blocked"
    (textPayload:"TCP_DENIED" OR textPayload:"NONE_NONE")
  EOT

  metric_descriptor {
    metric_kind  = "DELTA"
    value_type   = "INT64"
    unit         = "1"
    display_name = "Transparent Proxy Denied Requests"
  }
}

resource "google_monitoring_alert_policy" "transparent_proxy_denied" {
  display_name = "${var.name} Transparent proxy TCP_DENIED rate"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Transparent proxy TCP_DENIED requests is higher than expected"

    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"logging.googleapis.com/user/${google_logging_metric.transparent_proxy_denied.name}\""
      duration        = "0s"
      comparison      = "COMPARISON_GT"
      threshold_value = 1

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }
}

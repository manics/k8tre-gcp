# GKE Cluster Definition (using GKE native Cilium Dataplane V2, Cloud DNS, and Gateway API)

resource "google_container_cluster" "primary" {
  name               = var.cluster_name
  location           = local.cluster_location
  node_locations     = local.node_locations
  project            = var.project_id
  min_master_version = var.k8s_version

  release_channel {
    channel = "REGULAR"
  }

  # Remove the default node pool to manage node pools explicitly
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network
  subnetwork = var.subnetwork

  # GKE Native Cilium CNI (Dataplane V2): provides eBPF dataplane, kube-proxy
  # replacement, and CiliumNetworkPolicy support natively
  datapath_provider = "ADVANCED_DATAPATH"

  # GKE Native Cloud DNS for cluster DNS resolution
  dns_config {
    cluster_dns       = "CLOUD_DNS"
    cluster_dns_scope = "CLUSTER_SCOPE"
  }

  # GKE Native Gateway API controller & CRDs
  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.ip_range_pods
    services_secondary_range_name = var.ip_range_services
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.k8s_api_cidrs
      content {
        cidr_block   = cidr_blocks.value
        display_name = "Allowed CIDR ${cidr_blocks.key}"
      }
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  dynamic "database_encryption" {
    for_each = var.kms_key_name != null ? [var.kms_key_name] : []
    content {
      state    = "ENCRYPTED"
      key_name = database_encryption.value
    }
  }

  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "APISERVER",
      "CONTROLLER_MANAGER",
      "SCHEDULER",
      "WORKLOADS",
    ]
  }

  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "APISERVER",
      "SCHEDULER",
      "CONTROLLER_MANAGER",
      "STORAGE",
      "HPA",
      "POD",
      "DAEMONSET",
      "DEPLOYMENT",
      "STATEFULSET",
    ]

    # GKE Native Hubble Relay & Dataplane V2 observability metrics
    advanced_datapath_observability_config {
      enable_metrics = true
      enable_relay   = true
    }
  }

  addons_config {
    gcs_fuse_csi_driver_config {
      enabled = true
    }
    gcp_filestore_csi_driver_config {
      enabled = true
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  deletion_protection = false
}

resource "google_container_node_pool" "primary_nodes" {
  count          = (var.deployment_stage >= 1) ? 1 : 0
  name           = "${var.cluster_name}-wg1"
  location       = local.cluster_location
  node_locations = local.node_locations
  cluster        = google_container_cluster.primary.name
  node_count     = var.wg1_size
  project        = var.project_id

  autoscaling {
    min_node_count = 1
    max_node_count = var.wg1_max_size
  }

  management {
    auto_repair  = true
    auto_upgrade = var.autoupdate_nodes
  }

  node_config {
    machine_type    = var.instance_type_wg1
    disk_size_gb    = var.root_volume_size
    disk_type       = "pd-balanced"
    service_account = google_service_account.node_sa.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      cluster = var.cluster_name
    }

    tags = [
      "gke-node",
      "${var.cluster_name}-node",
    ]

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

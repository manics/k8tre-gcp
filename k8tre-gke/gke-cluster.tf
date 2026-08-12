# GKE Cluster Definition

resource "google_container_cluster" "primary" {
  name               = var.cluster_name
  location           = var.region
  project            = var.project_id
  min_master_version = var.k8s_version


  # We remove the default node pool to manage node pools explicitly
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network
  subnetwork = var.subnetwork

  ip_allocation_policy {
    cluster_secondary_range_name  = var.ip_range_pods
    services_secondary_range_name = var.ip_range_services
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
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

  gateway_api_config {
    channel = "CHANNEL_STANDARD"
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
  count      = (var.deployment_stage >= 1) ? 1 : 0
  name       = "${var.cluster_name}-wg1"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.wg1_size
  project    = var.project_id

  autoscaling {
    min_node_count = 1
    max_node_count = var.wg1_max_size
  }

  node_config {
    machine_type = var.instance_type_wg1
    disk_size_gb = var.root_volume_size
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      cluster = var.cluster_name
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}


######################################################################
# K8S Gateway CRDs and Optional Cilium Setup

data "http" "gateway_standard_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v${var.gateway_api_version}/standard-install.yaml"
}

locals {
  gateway_crds = provider::kubernetes::manifest_decode_multi(data.http.gateway_standard_crds.response_body)
  gateway_standard_crds_removed_status = [
    for manifest in local.gateway_crds : { for k, v in manifest : k => v if k != "status" }
  ]

  gateway_manifests = flatten([
    var.deployment_stage >= 1 ? [local.gateway_standard_crds_removed_status] : []
  ])
}

resource "kubernetes_manifest" "gateway_crds" {
  for_each = {
    for manifest in local.gateway_manifests :
    "${manifest.kind}--${manifest.metadata.name}" => manifest
  }

  manifest = each.value
}

resource "helm_release" "cilium" {
  count      = (var.deployment_stage >= 1) ? 1 : 0
  depends_on = [kubernetes_manifest.gateway_crds, google_container_node_pool.primary_nodes]

  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.cilium_version
  namespace  = "kube-system"

  wait = false

  set = [
    {
      name  = "k8sServiceHost"
      value = google_container_cluster.primary.endpoint
    },
    {
      name  = "k8sServicePort"
      value = "443"
    },
    {
      name  = "gatewayAPI.enabled"
      value = "true"
    },
    {
      name  = "hubble.enabled"
      value = "true"
    },
    {
      name  = "hubble.ui.enabled"
      value = "true"
    },
    {
      name  = "hubble.relay.enabled"
      value = "true"
    }
  ]
}


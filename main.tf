# Get IP of caller to optionally limit inbound connections
data "http" "myip" {
  url = "https://api.ipify.org"
}

locals {
  allow_ips = [
    for ip in var.allowed_cidrs :
    replace(ip, "/^myip$/", "${chomp(data.http.myip.response_body)}/32")
  ]

  gke_pods_cidr        = "10.1.0.0/16"
  gke_services_cidr    = "10.2.0.0/20"
  argocd_pods_cidr     = "10.3.0.0/16"
  argocd_services_cidr = "10.4.0.0/20"

  internal_cluster_cidrs = [
    var.private_subnets[0],
    local.gke_pods_cidr,
    local.argocd_pods_cidr,
  ]

  k8s_api_cidrs = distinct(concat(local.allow_ips, local.internal_cluster_cidrs))
}


######################################################################
# VPC & Networking
######################################################################

resource "google_compute_network" "vpc" {
  name                    = "${var.name}-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
  depends_on              = [google_project_service.required_apis]
}

resource "google_compute_subnetwork" "private_subnet" {
  name                     = "${var.name}-private-subnet"
  ip_cidr_range            = var.private_subnets[0]
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
  project                  = var.project_id

  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = local.gke_pods_cidr
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = local.gke_services_cidr
  }

  secondary_ip_range {
    range_name    = "argocd-pods"
    ip_cidr_range = local.argocd_pods_cidr
  }

  secondary_ip_range {
    range_name    = "argocd-services"
    ip_cidr_range = local.argocd_services_cidr
  }
}

resource "google_compute_subnetwork" "public_subnet" {
  name                     = "${var.name}-public-subnet"
  ip_cidr_range            = var.public_subnets[0]
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
  project                  = var.project_id
}

resource "google_compute_router" "router" {
  name    = "${var.name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
  project = var.project_id
}

resource "google_compute_router_nat" "nat" {
  count                              = (!var.require_outbound_proxy || !contains(var.outbound_proxy_cidrs, "0.0.0.0/0")) ? 1 : 0
  name                               = "${var.name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  project                            = var.project_id
}


######################################################################
# Main K8TRE Kubernetes (GKE)
######################################################################

module "k8tre-gke" {
  source = "./k8tre-gke"

  deployment_stage = var.deployment_stage
  project_id       = var.project_id
  region           = var.region
  zone             = var.zone
  number_azs       = var.number_availability_zones

  cluster_name           = var.name
  network                = google_compute_network.vpc.name
  subnetwork             = google_compute_subnetwork.private_subnet.name
  ip_range_pods          = "gke-pods"
  ip_range_services      = "gke-services"
  master_ipv4_cidr_block = "172.16.0.0/28"

  k8s_api_cidrs = local.k8s_api_cidrs

  root_volume_size = 200
  wg1_size         = 2
  wg1_max_size     = 2

  kms_key_name = google_kms_crypto_key.default-storage.id

  create_pod_identities = true
  hosted_zone_ids = concat(
    [module.dnsresolver.private-zone-id],
    var.create_public_zone ? [module.dnsresolver.public-zone-id] : []
  )

  github_oidc_rolename = var.enable_github_oidc ? "${var.name}-github-oidc" : null

  additional_admin_principals = var.additional_admin_principals

  # Storage
  gcs_mountable_buckets     = [google_storage_bucket.studydata.name]
  gcs_mountable_bucket_keys = [google_kms_crypto_key.default-storage.id]

  depends_on = [
    google_project_service.required_apis,
    google_kms_crypto_key_iam_member.gke_service_agent,
  ]
}


######################################################################
# ArgoCD K8TRE Kubernetes (GKE)
######################################################################

module "k8tre-argocd-gke" {
  source = "./k8tre-gke"

  deployment_stage = var.deployment_stage
  project_id       = var.project_id
  region           = var.region
  zone             = var.zone
  number_azs       = var.number_availability_zones

  cluster_name           = "${var.name}-argocd"
  network                = google_compute_network.vpc.name
  subnetwork             = google_compute_subnetwork.private_subnet.name
  ip_range_pods          = "argocd-pods"
  ip_range_services      = "argocd-services"
  master_ipv4_cidr_block = "172.16.0.16/28"

  k8s_api_cidrs = local.k8s_api_cidrs

  instance_type_wg1 = "e2-standard-2"
  wg1_size          = 1
  wg1_max_size      = 1

  kms_key_name = google_kms_crypto_key.default-storage.id

  create_pod_identities = false

  argocd_create_role          = true
  argocd_target_gke_access_sa = module.k8tre-gke.gke_access_service_account

  additional_admin_principals = var.additional_admin_principals

  depends_on = [
    google_project_service.required_apis,
    google_kms_crypto_key_iam_member.gke_service_agent,
  ]
}

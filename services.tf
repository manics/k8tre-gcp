######################################################################
# Enable required GCP Project APIs

locals {
  required_gcp_apis = toset(concat([
    "certificatemanager.googleapis.com",
    "cloudkms.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "dns.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ], var.enable_filestore_rwx ? ["file.googleapis.com"] : []))
}

resource "google_project_service" "required_apis" {
  for_each           = local.required_gcp_apis
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

data "google_project" "current" {
  project_id = var.project_id
  depends_on = [google_project_service.required_apis]
}

data "google_storage_project_service_account" "gcs_account" {
  project    = var.project_id
  depends_on = [google_project_service.required_apis]
}


######################################################################
# Storage encryption key (GCP Cloud KMS) & Service Agent Permissions

resource "google_kms_key_ring" "default-storage" {
  name       = "${var.name}-keyring"
  location   = var.region
  project    = var.project_id
  depends_on = [google_project_service.required_apis]
}

resource "google_kms_crypto_key" "default-storage" {
  name            = "${var.name}-default-storage"
  key_ring        = google_kms_key_ring.default-storage.id
  rotation_period = "2592000s" # 30 days
}

resource "google_kms_crypto_key_iam_member" "gcs_service_agent" {
  crypto_key_id = google_kms_crypto_key.default-storage.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

resource "google_kms_crypto_key_iam_member" "compute_service_agent" {
  crypto_key_id = google_kms_crypto_key.default-storage.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@compute-system.iam.gserviceaccount.com"
}

resource "google_kms_crypto_key_iam_member" "gke_service_agent" {
  crypto_key_id = google_kms_crypto_key.default-storage.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@container-engine-robot.iam.gserviceaccount.com"
}

resource "google_kms_crypto_key_iam_member" "filestore_service_agent" {
  count         = var.enable_filestore_rwx ? 1 : 0
  crypto_key_id = google_kms_crypto_key.default-storage.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@cloud-filer.iam.gserviceaccount.com"
}


######################################################################
# Bucket for study data (GCS)

resource "google_storage_bucket" "studydata" {
  name                        = "${var.name}-studydata-${var.project_id}"
  location                    = var.region
  project                     = var.project_id
  force_destroy               = false
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true

  encryption {
    default_kms_key_name = google_kms_crypto_key.default-storage.id
  }

  depends_on = [google_kms_crypto_key_iam_member.gcs_service_agent]
}


######################################################################
# Bucket for storing configuration

resource "google_storage_bucket" "services_config" {
  name                        = "${var.name}-config-${var.project_id}"
  location                    = var.region
  project                     = var.project_id
  force_destroy               = true
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
}


######################################################################
# Private Google Access Route & DNS (GCP Equivalent of AWS VPC Endpoints)
# Ensures Google APIs (*.googleapis.com) route via Private Google Access
# rather than through the Squid transparent proxy when 0.0.0.0/0 is proxied.

resource "google_compute_route" "private_google_access" {
  name             = "${var.name}-private-google-access"
  dest_range       = "199.36.153.8/30"
  network          = google_compute_network.vpc.name
  next_hop_gateway = "default-internet-gateway"
  priority         = 800
  project          = var.project_id
}

resource "google_dns_managed_zone" "googleapis" {
  name        = "${var.name}-private-googleapis"
  dns_name    = "googleapis.com."
  description = "Private Google Access DNS zone for *.googleapis.com"
  visibility  = "private"
  project     = var.project_id

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc.id
    }
  }
}

resource "google_dns_record_set" "googleapis_a" {
  managed_zone = google_dns_managed_zone.googleapis.name
  name         = "private.googleapis.com."
  type         = "A"
  ttl          = 300
  rrdatas      = ["199.36.153.8", "199.36.153.9", "199.36.153.10", "199.36.153.11"]
  project      = var.project_id
}

resource "google_dns_record_set" "googleapis_cname" {
  managed_zone = google_dns_managed_zone.googleapis.name
  name         = "*.googleapis.com."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["private.googleapis.com."]
  project      = var.project_id
}


######################################################################
# DNS (Cloud DNS)

module "dnsresolver" {
  source = "./dnsresolver"
  name   = var.dns_domain

  vpc = google_compute_network.vpc.id

  static-ttl = 3600
  static     = []

  private-records = {
    "_ldap._tcp.gc._msdcs.ad SRV" = ["0 100 3268 dc0.ad.${var.dns_domain}."]
    "_kerberos._tcp.ad SRV"       = ["0 100 88 dc0.ad.${var.dns_domain}."]
    "_kerberos._udp.ad SRV"       = ["0 100 88 dc0.ad.${var.dns_domain}."]
    "_ldap._tcp.ad SRV"           = ["0 100 389 dc0.ad.${var.dns_domain}."]
    "_ldap._udp.ad SRV"           = ["0 100 389 dc0.ad.${var.dns_domain}."]
  }

  create_public_zone = var.create_public_zone

  depends_on = [google_project_service.required_apis]
}


######################################################################
# Certificate

module "certificate" {
  count = var.request_certificate == "none" ? 0 : 1

  source = "./certificate"

  domain_name               = "*.${var.dns_domain}"
  subject_alternative_names = [var.dns_domain]

  request_gcp_certificate = var.request_certificate == "gcp" ? true : false

  depends_on = [google_project_service.required_apis]
}


######################################################################
# Transparent proxy

module "transparent-proxy" {
  count = var.require_outbound_proxy ? 1 : 0

  source                = "./transparent-proxy"
  name                  = var.name
  project_id            = var.project_id
  region                = var.region
  zone                  = var.zone
  network               = google_compute_network.vpc.name
  public_subnet         = google_compute_subnetwork.public_subnet.name
  allowed_source_ranges = local.internal_cluster_cidrs
  outbound_proxy_cidrs  = var.outbound_proxy_cidrs

  gcs_config_bucket = google_storage_bucket.services_config.name
  allowed_domains   = concat(var.default_outbound_proxy_allowed_domains, var.additional_outbound_proxy_allowed_domains)
}

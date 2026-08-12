######################################################################
# Storage encryption key (GCP Cloud KMS)

resource "google_kms_key_ring" "default-storage" {
  name     = "${var.name}-keyring"
  location = var.region
  project  = var.project_id
}

resource "google_kms_crypto_key" "default-storage" {
  name            = "${var.name}-default-storage"
  key_ring        = google_kms_key_ring.default-storage.id
  rotation_period = "2592000s" # 30 days
}


######################################################################
# Filestore (RWX Shared File System)

module "filestore" {
  source       = "./filestore"
  name         = var.name
  network      = google_compute_network.vpc.name
  location     = var.zone
  kms_key_name = google_kms_crypto_key.default-storage.id
}


######################################################################
# Bucket for study data (GCS)

resource "google_storage_bucket" "studydata" {
  name                     = "${var.name}-studydata-${var.project_id}"
  location                 = var.region
  project                  = var.project_id
  force_destroy            = false
  public_access_prevention = "enforced"

  encryption {
    default_kms_key_name = google_kms_crypto_key.default-storage.id
  }
}


######################################################################
# Bucket for storing configuration

resource "google_storage_bucket" "services_config" {
  name                     = "${var.name}-config-${var.project_id}"
  location                 = var.region
  project                  = var.project_id
  force_destroy            = true
  public_access_prevention = "enforced"
}


######################################################################
# DNS (Cloud DNS)

module "dnsresolver" {
  source = "./dnsresolver"
  name   = var.dns_domain

  vpc = google_compute_network.vpc.id

  alarm_topics = []

  static-ttl = 3600
  static     = []

  private-records = {
    "_ldap._tcp.gc._msdcs.ad SRV" = ["0 100 3268 dc0.ad.${var.dns_domain}"]
    "_kerberos._tcp.ad SRV"       = ["0 100 88 dc0.ad.${var.dns_domain}"]
    "_kerberos._udp.ad SRV"       = ["0 100 88 dc0.ad.${var.dns_domain}"]
    "_ldap._tcp.ad SRV"           = ["0 100 389 dc0.ad.${var.dns_domain}"]
    "_ldap._udp.ad SRV"           = ["0 100 389 dc0.ad.${var.dns_domain}"]
  }

  allowed_domains = ["*."]

  create_public_zone = var.create_public_zone
}


######################################################################
# Certificate

module "certificate" {
  count = var.request_certificate == "none" ? 0 : 1

  source = "./certificate"

  domain_name               = "*.${var.dns_domain}"
  subject_alternative_names = [var.dns_domain]

  request_gcp_certificate = var.request_certificate == "gcp" ? true : false
}


######################################################################
# Transparent proxy

module "transparent-proxy" {
  count = var.require_outbound_proxy ? 1 : 0

  source               = "./transparent-proxy"
  name                 = var.name
  project_id           = var.project_id
  region               = var.region
  zone                 = var.zone
  network              = google_compute_network.vpc.name
  public_subnet        = google_compute_subnetwork.public_subnet.name
  outbound_proxy_cidrs = var.outbound_proxy_cidrs

  gcs_config_bucket = google_storage_bucket.services_config.name
  allowed_domains   = concat(var.default_outbound_proxy_allowed_domains, var.additional_outbound_proxy_allowed_domains)
}

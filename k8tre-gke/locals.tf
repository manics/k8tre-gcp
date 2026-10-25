# Locals that may be used in multiple places

locals {
  cluster_location = var.number_azs == 1 ? var.zone : var.region
  node_locations   = var.number_azs > 1 ? slice(["${var.region}-a", "${var.region}-b", "${var.region}-c"], 0, var.number_azs) : null

  create_pod_identities            = var.create_pod_identities ? 1 : 0
  create_external_dns_pod_identity = (var.create_pod_identities && length(var.hosted_zone_ids) > 0) ? 1 : 0

  enable_gcs_csi              = (length(var.gcs_mountable_buckets) > 0) ? 1 : 0
  create_gcs_csi_pod_identity = (var.create_pod_identities && local.enable_gcs_csi > 0) ? 1 : 0
}

# Setup K8TRE and prerequisites


######################################################################
# Standard storage classes required by K8TRE
#
# - rwo-default: ReadWriteOnce backed by GCE Persistent Disk (pd-balanced, CMEK encrypted)
# - rwx-default: ReadWriteMany with two configurable options:
#     1. Default (enable_filestore_rwx = false): Cheap in-cluster NFS server + dynamic
#        provisioner backed by a GCE Persistent Disk (rwo-default), suitable for dev
#        and small production deployments (~$10/mo for 100 GiB).
#     2. Large-scale production (enable_filestore_rwx = true): GCP Filestore CSI dynamic
#        provisioning (supporting Filestore Multishares on Enterprise tier to share a
#        Filestore instance across up to 80 PVCs).

resource "kubernetes_storage_class" "rwo-default" {
  count = (var.deployment_stage >= 2) ? 1 : 0

  metadata {
    name = "rwo-default"
    annotations = {
      "description" = "ReadWriteOnce - Single pod read-write access"
    }
  }
  storage_provisioner = "pd.csi.storage.gcp.io"
  reclaim_policy      = "Delete"
  parameters = {
    type                    = "pd-balanced"
    disk-encryption-kms-key = google_kms_crypto_key.default-storage.id
  }
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  depends_on = [google_kms_crypto_key_iam_member.compute_service_agent]

  provider = kubernetes.k8tre-dev
}

# Option 1 (Default): Cheap in-cluster NFS dynamic provisioner backed by GCE Persistent Disk
resource "kubernetes_namespace" "nfs_provisioner" {
  count = (var.deployment_stage >= 2 && !var.enable_filestore_rwx) ? 1 : 0

  metadata {
    name = "nfs-provisioner"
  }

  provider = kubernetes.k8tre-dev
}

resource "helm_release" "nfs_server_provisioner" {
  count = (var.deployment_stage >= 2 && !var.enable_filestore_rwx) ? 1 : 0

  name       = "nfs-server-provisioner"
  repository = "https://kubernetes-sigs.github.io/nfs-ganesha-server-and-external-provisioner/"
  chart      = "nfs-server-provisioner"
  version    = "1.8.0"
  namespace  = kubernetes_namespace.nfs_provisioner[0].metadata[0].name

  values = [
    yamlencode({
      persistence = {
        enabled      = true
        storageClass = kubernetes_storage_class.rwo-default[0].metadata[0].name
        size         = "${var.rwx_nfs_disk_size_gb}Gi"
      }
      storageClass = {
        create               = true
        name                 = "rwx-default"
        defaultClass         = false
        reclaimPolicy        = "Delete"
        allowVolumeExpansion = true
      }
    })
  ]

  depends_on = [kubernetes_storage_class.rwo-default, kubernetes_namespace.nfs_provisioner]

  provider = helm.k8tre-dev
}

# Option 2 (Production): GCP Filestore CSI dynamic provisioning (disabled by default)
resource "kubernetes_storage_class" "rwx-default-filestore" {
  count = (var.deployment_stage >= 2 && var.enable_filestore_rwx) ? 1 : 0

  metadata {
    name = "rwx-default"
    annotations = {
      "description" = "ReadWriteMany - Multi-pod shared read-write access (Filestore CSI)"
    }
  }
  storage_provisioner = "filestore.csi.storage.gcp.io"
  reclaim_policy      = "Delete"
  parameters = merge(
    {
      tier    = var.rwx_filestore_tier
      network = google_compute_network.vpc.name
    },
    var.rwx_filestore_tier == "enterprise" ? {
      multishare      = "true"
      max-volume-size = "1024Gi"
    } : {},
    contains(["enterprise", "zonal", "regional"], var.rwx_filestore_tier) ? {
      instance-encryption-kms-key = google_kms_crypto_key.default-storage.id
    } : {},
  )
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  depends_on = [google_kms_crypto_key_iam_member.filestore_service_agent]

  provider = kubernetes.k8tre-dev
}


######################################################################
# ArgoCD

resource "kubernetes_namespace" "argocd" {
  count = (var.deployment_stage >= 2) ? 1 : 0

  metadata {
    name = "argocd"
  }

  provider = kubernetes.k8tre-dev-argocd
}

# Create the plugin config map first so that it can be referenced later in the helm release.
resource "kubernetes_config_map" "cmp_plugin" {
  count = (var.deployment_stage >= 2) ? 1 : 0

  metadata {
    name      = "cmp-plugin"
    namespace = kubernetes_namespace.argocd[0].metadata[0].name
  }

  data = {
    "plugin.yaml" = <<-EOT
      apiVersion: argoproj.io/v1alpha1
      kind: ConfigManagementPlugin
      metadata:
        name: kustomize-with-envsubst
      spec:
        version: v1.0
        generate:
          command: [sh, -c]
          args:
            - >-
              kustomize build --enable-helm --load-restrictor LoadRestrictionsNone . |
                sed "
                  s/\$${ENVIRONMENT}/$${ARGOCD_ENV_ENVIRONMENT}/g;
                  s/\$${DOMAIN}/$${ARGOCD_ENV_DOMAIN}/g;
                  s/\\.ENVIRONMENT\\./.$${ARGOCD_ENV_ENVIRONMENT}./g;
                  s/\\.DOMAIN/.$${ARGOCD_ENV_DOMAIN}/g;
                  s/^ENVIRONMENT$/$${ARGOCD_ENV_ENVIRONMENT}/g;
                  s/^DOMAIN$/$${ARGOCD_ENV_DOMAIN}/g;

                  s/\$${CLUSTER_NAME}/$${ARGOCD_ENV_CLUSTER_NAME}/g;
                  s/\$${REGION}/$${ARGOCD_ENV_REGION}/g;
                "
    EOT
  }

  provider = kubernetes.k8tre-dev-argocd
}

# https://github.com/argoproj/argo-helm/tree/argo-cd-9.0.5/charts/argo-cd
resource "helm_release" "argocd" {
  count = (var.deployment_stage >= 2) ? 1 : 0

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = kubernetes_namespace.argocd[0].metadata[0].name

  set = [
    {
      name  = "global.logging.level"
      value = "debug"
    },
    {
      name  = "configs.params.server.insecure"
      value = "true"
    },
    # https://github.com/argoproj/argo-helm/issues/1817
    {
      name  = "configs.cm.kustomize\\.buildOptions"
      value = "--enable-helm --load-restrictor LoadRestrictionsNone"
    },
  ]

  # Specify the custom plugin extra containers, volumes, and GKE Workload Identity annotations.
  values = [
    yamlencode({
      controller = {
        serviceAccount = {
          annotations = {
            "iam.gke.io/gcp-service-account" = module.k8tre-argocd-gke.argocd_service_account_email
          }
        }
      }
      server = {
        serviceAccount = {
          annotations = {
            "iam.gke.io/gcp-service-account" = module.k8tre-argocd-gke.argocd_service_account_email
          }
        }
      }
      applicationSet = {
        serviceAccount = {
          annotations = {
            "iam.gke.io/gcp-service-account" = module.k8tre-argocd-gke.argocd_service_account_email
          }
        }
      }
      repoServer = {
        volumes = [
          {
            name = "cmp-plugin"
            configMap = {
              name = "cmp-plugin"
            }
          }
        ]
        extraContainers = [
          {
            name    = "cmp-kustomize-envsubst"
            command = ["/var/run/argocd/argocd-cmp-server"]
            image   = "quay.io/argoproj/argocd:{{ .Chart.AppVersion }}"
            securityContext = {
              runAsNonRoot             = true
              runAsUser                = 999
              allowPrivilegeEscalation = false
              readOnlyRootFilesystem   = true
              capabilities = {
                drop = ["ALL"]
              }
              seccompProfile = {
                type = "RuntimeDefault"
              }
            }
            volumeMounts = [
              {
                mountPath = "/var/run/argocd"
                name      = "var-files"
              },
              {
                mountPath = "/home/argocd/cmp-server/plugins"
                name      = "plugins"
              },
              {
                mountPath = "/tmp"
                name      = "tmp"
              },
              {
                mountPath = "/home/argocd/cmp-server/config/plugin.yaml"
                subPath   = "plugin.yaml"
                name      = "cmp-plugin"
              }
            ]
          }
        ]
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd, kubernetes_config_map.cmp_plugin]

  provider = helm.k8tre-dev-argocd
}


# Add k8tre-dev cluster to ArgoCD (using GKE Workload Identity & internal private endpoint)
resource "kubernetes_secret" "argocd-cluster-k8tre-dev" {
  count = (var.deployment_stage >= 2) ? 1 : 0

  metadata {
    name      = "argocd-cluster-${module.k8tre-gke.cluster_name}"
    namespace = kubernetes_namespace.argocd[0].metadata[0].name
    labels = merge(
      { "argocd.argoproj.io/secret-type" = "cluster" },
      var.k8tre_cluster_labels,
      {
        "cluster-name" : module.k8tre-gke.cluster_name,
        "external-domain" : var.dns_domain,
        "region" : var.region,
      },
      var.k8tre_cluster_label_overrides,
    )
  }
  data = {
    config = jsonencode({
      execProviderConfig = {
        command    = "argocd-k8s-auth"
        args       = ["gcp"]
        apiVersion = "client.authentication.k8s.io/v1beta1"
      }
      tlsClientConfig = {
        caData = module.k8tre-gke.cluster_ca_certificate
      }
    })
    name   = module.k8tre-gke.cluster_name
    server = "https://${module.k8tre-gke.cluster_private_endpoint}"
  }

  provider = kubernetes.k8tre-dev-argocd
}

# https://github.com/k8tre/k8tre/blob/main/app_of_apps/root-app-of-apps.yaml
data "http" "k8tre-root-app" {
  count = (var.deployment_stage >= 3) && var.install_k8tre ? 1 : 0

  url = "https://github.com/${var.k8tre_github_repo}/raw/refs/heads/${var.k8tre_github_ref}/app_of_apps/root-app-of-apps.yaml"
}

resource "kubernetes_manifest" "argocd-root-app-of-apps" {
  count = (var.deployment_stage >= 3) && var.install_k8tre ? 1 : 0

  manifest = yamldecode(
    replace(
      replace(
        data.http.k8tre-root-app[0].response_body,
        "main", var.k8tre_github_ref
      ),
      "k8tre/k8tre", var.k8tre_github_repo
    )
  )

  # This is a CRD, so ArgoCD must be deployed first
  depends_on = [helm_release.argocd]

  provider = kubernetes.k8tre-dev-argocd
}

locals {
  additional_k8s_manifests = (var.deployment_stage >= 3) ? toset(var.additional_k8s_manifests) : toset([])
}

resource "kubernetes_manifest" "additional-argocd-app" {
  for_each = local.additional_k8s_manifests

  manifest = yamldecode(file(each.value))

  depends_on = [helm_release.argocd]

  provider = kubernetes.k8tre-dev-argocd
}

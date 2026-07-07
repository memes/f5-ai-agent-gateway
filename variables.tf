variable "project_id" {
  type     = string
  nullable = false
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "The project_id value must be a valid Google Cloud project identifier"
  }
  description = <<-EOD
  The Google Cloud project identifier that will contain the resources.
  EOD
}

variable "name" {
  type     = string
  nullable = false
  validation {
    # The generated service account names has a limit of 30 characters, including the '-gke' suffix. Validate that
    # var.name is 1 <= length(var.name) <=26.
    condition     = can(regex("^[a-z][a-z0-9-]{0,24}[a-z0-9]$", var.name))
    error_message = "The name variable must be RFC1035 compliant and between 1 and 26 characters in length."
  }
  description = <<-EOD
  The base name to use for resources created by this module.
  EOD
}

variable "region" {
  type     = string
  nullable = false
  validation {
    condition     = can(regex("^[a-z]{2,}-[a-z]{2,}[0-9]$", var.region))
    error_message = "The region must be a valid Google Cloud region name."
  }
  default     = "us-central1"
  description = <<-EOD
  The Compute Engine region name in which to create resources. Default is 'us-central1'.
  EOD
}

variable "labels" {
  type     = map(string)
  nullable = true
  validation {
    # GCP resource labels must be lowercase alphanumeric, underscore or hyphen,
    # and the key must be <= 63 characters in length
    condition     = var.labels == null ? true : alltrue([for k, v in var.labels : can(regex("^[a-z][a-z0-9_-]{0,62}$", k)) && can(regex("^[a-z0-9_-]{0,63}$", v))])
    error_message = "Each label key:value pair must match expectations."
  }
  default     = {}
  description = <<-EOD
  An optional map of key:value labels to apply to the resources. Default value is an empty map.
  NOTE: The effective set of labels will include some fixed values in addition to these.
  EOD
}

variable "repositories" {
  type     = set(string)
  nullable = true
  validation {
    condition     = var.repositories == null ? true : alltrue([for repo in var.repositories : can(regex("^[a-z]{2,}(?:-[a-z]+[1-9])?-docker.pkg.dev/[^/]+/[^/]+", repo))])
    error_message = "Each repository entry must be a valid Artifact Registry repository."
  }
  default     = null
  description = <<-EOD
  Existing private Artifact Registries that will be used for deployments. The service account for the clusters will be
  given automatic IAM role to pull from these registries if it is not empty.
  EOD
}

variable "enforce_iap" {
  type        = bool
  nullable    = false
  default     = false
  description = <<-EOD
  If true, the IAP policy associated with the Agent Egress Gateway will be enforced; if false (default), IAP policy will
  be set to DRY_RUN which will log policy violations but not block them.
  EOD
}

variable "service_extension_container_image" {
  type        = string
  nullable    = false
  description = <<-EOD
The qualified container image to use as a service extension on this VM.
You must supply this value with a valid private Artifact or Container Repository
identifier, or a public repo identifier.
EOD
}

variable "public_dns" {
  type = object({
    base_domain     = string
    managed_zone_id = optional(string)
  })
  nullable = true
  validation {
    condition     = can(regex("^(?:[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\\.)+[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]$", var.public_dns.base_domain)) && (coalesce(var.public_dns.managed_zone_id, "unspecified") == "unspecified" ? true : can(regex("projects/[a-z][a-z0-9-]{4,28}[a-z0-9]/managedZones/[a-z][a-z0-9-]{0,61}[a-z0-9]?$", var.public_dns.managed_zone_id)))
    error_message = "The base_domain field of public_dns must be a valid DNS zone name, and, if provided, the Cloud DNS Managed Zone id must be valid."
  }
  description = <<-EOD
  An optional value, `base_domain` sets the root for public TLS certificate creation and DNS challenges, and becomes the
  base for a VPC private DNS zone for GKE services (`internal.{public_dns.base_domain}`). An optional `managed_zone_id`
  value containing a Cloud DNS Managed Zone identifier can be provided to have the DNS challenges added automatically.
  EOD
}

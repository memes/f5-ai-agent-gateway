locals {
  internal_dns_domain = endswith(var.internal_dns_domain, ".") ? var.internal_dns_domain : format("%s.", var.internal_dns_domain)
  extension_dns       = format("extension.%s", local.internal_dns_domain)
}


# resource "google_compute_address" "alb" {
#   project      = var.project_id
#   name         = var.name
#   address_type = "INTERNAL"
#   purpose      = "GCE_ENDPOINT"
#   region       = var.region
#   subnetwork   = google_compute_subnetwork.primary.self_link
# }


resource "google_compute_address" "ilb" {
  project      = var.project_id
  name         = format("%s-ilb", var.name)
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
  region       = var.region
  subnetwork   = google_compute_subnetwork.primary.self_link
}

resource "google_dns_managed_zone" "internal" {
  project       = var.project_id
  name          = var.name
  description   = "F5 AI Agent Gateway service extension testing"
  dns_name      = local.internal_dns_domain
  labels        = var.labels
  visibility    = "private"
  force_destroy = true

  private_visibility_config {
    networks {
      network_url = google_compute_network.network.self_link
    }
  }
}

resource "google_dns_record_set" "ilb" {
  project      = var.project_id
  managed_zone = google_dns_managed_zone.internal.name
  name         = format("extension.%s", google_dns_managed_zone.internal.dns_name)
  type         = "A"
  ttl          = 300
  rrdatas = [
    google_compute_address.ilb.address,
  ]

  depends_on = [
    google_compute_address.ilb,
    google_dns_managed_zone.internal,
  ]
}

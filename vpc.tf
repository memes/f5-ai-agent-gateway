resource "google_compute_network" "network" {
  project                         = var.project_id
  name                            = var.name
  description                     = "F5 AI Agent Gateway service extension testing"
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = false
  enable_ula_internal_ipv6        = false
}

resource "google_compute_subnetwork" "primary" {
  project                    = var.project_id
  name                       = var.name
  network                    = google_compute_network.network.id
  ip_cidr_range              = "10.0.0.0/16"
  private_ip_google_access   = false
  private_ipv6_google_access = null
  region                     = var.region
  stack_type                 = "IPV4_ONLY"
  ipv6_access_type           = null
}

# Create a VPC subnet for PSC attached service providers
resource "google_compute_subnetwork" "psc" {
  project                    = var.project_id
  name                       = format("%s-psc", var.name)
  network                    = google_compute_network.network.self_link
  ip_cidr_range              = "172.18.0.0/24"
  private_ip_google_access   = false
  private_ipv6_google_access = null
  region                     = var.region
  stack_type                 = "IPV4_ONLY"
  ipv6_access_type           = null
}

resource "google_compute_network_attachment" "psc" {
  project     = var.project_id
  name        = var.name
  description = "F5 AI Agent Gateway service extension testing"
  region      = var.region
  subnetworks = [
    google_compute_subnetwork.primary.self_link
  ]
  # TODO(@memes): Review this with Google as prefer to explicitly list the producer projects
  connection_preference = "ACCEPT_AUTOMATIC"
}

# Allow IAP access to the VM instance.
resource "google_compute_firewall" "iap" {
  project     = google_compute_network.network.project
  name        = format("%s-allow-iap", var.name)
  network     = google_compute_network.network.id
  description = "Allow IAP ingress to VM instances"
  direction   = "INGRESS"
  priority    = 900
  source_ranges = [
    "35.235.240.0/20",
  ]
  target_service_accounts = [
    google_service_account.sa.email,
  ]
  allow {
    protocol = "tcp"
    ports = [
      22,
      80,
      443,
      8080,
    ]
  }
}

resource "google_compute_firewall" "allow_primary" {
  project   = var.project_id
  name      = format("%s-allow-primary", var.name)
  network   = google_compute_network.network.self_link
  direction = "INGRESS"
  priority  = 900
  source_ranges = [
    google_compute_subnetwork.primary.ip_cidr_range,
  ]
  target_service_accounts = [
    google_service_account.sa.email,
  ]

  allow {
    protocol = "tcp"
    ports = [
      80,
      443,
      8080,
    ]
  }
}

resource "google_compute_firewall" "allow_psc" {
  project   = var.project_id
  name      = format("%s-allow-psc", var.name)
  network   = google_compute_network.network.self_link
  direction = "INGRESS"
  priority  = 900
  source_ranges = [
    google_compute_subnetwork.psc.ip_cidr_range,
  ]
  target_service_accounts = [
    google_service_account.sa.email,
  ]

  allow {
    protocol = "tcp"
    ports = [
      80,
      443,
      8080,
    ]
  }
}

resource "google_compute_firewall" "allow_hc" {
  project   = var.project_id
  name      = format("%s-allow-hc", var.name)
  network   = google_compute_network.network.self_link
  direction = "INGRESS"
  priority  = 900
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16",
    "35.235.240.0/20",
  ]
  target_service_accounts = [
    google_service_account.sa.email,
  ]

  allow {
    protocol = "tcp"
    ports = [
      80,
    ]
  }
}

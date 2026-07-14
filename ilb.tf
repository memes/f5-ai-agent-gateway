resource "google_compute_region_health_check" "ilb" {
  project             = var.project_id
  name                = format("%s-ilb", var.name)
  region              = var.region
  timeout_sec         = 2
  check_interval_sec  = 5
  healthy_threshold   = 1
  unhealthy_threshold = 2

  http_health_check {
    port               = "80"
    port_specification = "USE_FIXED_PORT"
    request_path       = "/"
  }
}

resource "google_compute_region_backend_service" "ilb" {
  project               = var.project_id
  name                  = format("%s-ilb", var.name)
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL"
  timeout_sec           = 120

  health_checks = [
    google_compute_region_health_check.ilb.id,
  ]

  backend {
    group          = google_compute_region_instance_group_manager.mig.instance_group
    balancing_mode = "CONNECTION"
  }
}

resource "google_compute_forwarding_rule" "ilb" {
  project               = var.project_id
  name                  = var.name
  region                = var.region
  ip_protocol           = "TCP"
  ip_address            = google_compute_address.ilb.id
  all_ports             = true
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.ilb.id
  network               = google_compute_network.network.id
  subnetwork            = google_compute_subnetwork.primary.id
}

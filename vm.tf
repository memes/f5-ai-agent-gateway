locals {
  ar_repos = var.repositories == null ? {} : { for name in var.repositories : regex("^.*-docker\\.pkg\\.dev/[^/]+/([^/]+)", name)[0] => { location = regex("^(.*)-docker", name)[0], project = regex("docker\\.pkg\\.dev/([^/]+)/", name)[0] } if can(regex("^.+-docker\\.pkg\\.dev/[^/]+/[^/]+", name)) }
}


resource "google_service_account" "sa" {
  project      = var.project_id
  account_id   = var.name
  display_name = "F5 AI Agent Gateway service extension testing"
}

resource "google_project_iam_member" "roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/compute.osLogin",
  ])
  project = var.project_id
  role    = each.value
  member  = google_service_account.sa.member
}


# For the unique set of AR repos, assign reader role to the service account
# at each unique repo root.
resource "google_artifact_registry_repository_iam_member" "ar" {
  for_each   = local.ar_repos
  project    = each.value.project
  location   = each.value.location
  repository = each.key
  role       = "roles/artifactregistry.reader"
  member     = google_service_account.sa.member
}

resource "google_compute_region_health_check" "extension" {
  project             = var.project_id
  name                = var.name
  region              = var.region
  timeout_sec         = 2
  check_interval_sec  = 10
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port               = 80
    port_specification = "USE_FIXED_PORT"
    request_path       = "/"
  }
}

resource "google_compute_region_instance_template" "extension" {
  project              = var.project_id
  name_prefix          = format("%s-", var.name)
  description          = "Service extension host for F5 AI Agent Gateway testing"
  instance_description = "Service extension host for F5 AI Agent Gateway testing"
  region               = var.region
  machine_type         = "e2-medium"

  service_account {
    email = google_service_account.sa.email
    scopes = [
      "cloud-platform",
    ]
  }

  disk {
    source_image = data.google_compute_image.cos.self_link
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
    disk_type    = "pd-standard"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.primary.self_link
    access_config {}
  }

  metadata = {
    enable-oslogin               = "TRUE"
    google-logging-enabled       = "TRUE"
    google-logging-use-fluentbit = "TRUE"
    user-data = templatefile(format("%s/templates/cloud-config.yaml", path.module), {
      docker_credential_registries = toset(
        [for repo in local.ar_repos : format("%s-docker.pkg.dev", repo.location)]
      )
      service_extension_container_image = var.service_extension_container_image
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "google_compute_region_instance_group_manager" "mig" {
  project            = var.project_id
  name               = var.name
  base_instance_name = var.name
  region             = var.region
  target_size        = 1
  version {
    instance_template = google_compute_region_instance_template.extension.id
  }

  named_port {
    name = "http2"
    port = 443
  }

  named_port {
    name = "h2c"
    port = 8080
  }

  named_port {
    name = "health-check"
    port = 80
  }

  auto_healing_policies {
    health_check      = google_compute_region_health_check.extension.id
    initial_delay_sec = 60
  }

  update_policy {
    type                           = "PROACTIVE"
    instance_redistribution_type   = "NONE"
    minimal_action                 = "REPLACE"
    most_disruptive_allowed_action = "REPLACE"
    max_surge_fixed                = length(data.google_compute_zones.zones.names)
    max_unavailable_fixed          = length(data.google_compute_zones.zones.names)
    replacement_method             = "SUBSTITUTE"
  }

  instance_lifecycle_policy {
    force_update_on_repair    = "YES"
    default_action_on_failure = "REPAIR"
    on_failed_health_check    = "DEFAULT_ACTION"
  }
}

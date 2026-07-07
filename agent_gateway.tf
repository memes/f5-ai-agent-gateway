
# tflint-ignore: terraform_required_providers
resource "google_network_services_agent_gateway" "egress" {
  provider    = google-beta
  project     = var.project_id
  name        = var.name
  description = "F5 AI Agent Gateway service extension testing"
  location    = var.region
  protocols = [
    "MCP",
  ]
  google_managed {
    governed_access_path = "AGENT_TO_ANYWHERE"
  }

  network_config {
    egress {
      network_attachment = google_compute_network_attachment.psc.id
    }

    dns_peering_config {
      domains = [
        local.internal_dns_zone,
      ]
      target_project = google_compute_network.network.project
      target_network = google_compute_network.network.id
    }
  }

  registries = [
    format("//agentregistry.googleapis.com/projects/%s/locations/%s", data.google_project.project.project_id, var.region),
  ]
}

resource "google_network_services_authz_extension" "iap" {
  project  = var.project_id
  name     = format("%s-iap", var.name)
  location = var.region
  service  = "iap.googleapis.com"
  metadata = merge(
    {
      "iapPolicyVersion" = "V1"
    },
    var.enforce_iap ? {} : {
      "iamEnforcementMode" = "DRY_RUN"
    },
  )
  timeout = "1s"
}

resource "google_network_security_authz_policy" "iap" {
  project        = var.project_id
  name           = format("%s-iap", var.name)
  location       = var.region
  policy_profile = "REQUEST_AUTHZ"
  action         = "CUSTOM"
  target {
    resources = [
      google_network_services_agent_gateway.egress.id,
    ]
  }
  custom_provider {
    authz_extension {
      resources = [
        google_network_services_authz_extension.iap.id,
      ]
    }
  }
}

resource "google_network_services_authz_extension" "f5-ai-ext-content" {
  project     = var.project_id
  name        = format("%s-content", var.name)
  location    = var.region
  service     = trimsuffix(local.extension_dns, ".")
  fail_open   = true
  wire_format = "EXT_PROC_GRPC"
  timeout     = "10s"
}

resource "google_network_security_authz_policy" "f5-ai-ext-content" {
  project        = var.project_id
  name           = format("%s-content", var.name)
  location       = var.region
  policy_profile = "CONTENT_AUTHZ"
  action         = "CUSTOM"
  target {
    resources = [
      google_network_services_agent_gateway.egress.id,
    ]
  }
  custom_provider {
    authz_extension {
      resources = [
        google_network_services_authz_extension.f5-ai-ext-content.id,
      ]
    }
  }
}

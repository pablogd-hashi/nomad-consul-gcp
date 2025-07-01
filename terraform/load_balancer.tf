# DNS Zone (conditionally created if dns_zone_name is provided)
data "google_dns_managed_zone" "dns_zone" {
  count = var.dns_zone_name != "" ? 1 : 0
  name  = var.dns_zone_name
}

# DNS records for applications (only if DNS zone is provided)
resource "google_dns_record_set" "terramino" {
  count        = var.dns_zone_name != "" ? 1 : 0
  name         = "terramino-${var.cluster_name}.${data.google_dns_managed_zone.dns_zone[0].dns_name}"
  managed_zone = data.google_dns_managed_zone.dns_zone[0].name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_instance.nomad_clients[0].network_interface[0].access_config[0].nat_ip]
}

resource "google_dns_record_set" "traefik" {
  count        = var.dns_zone_name != "" ? 1 : 0
  name         = "traefik-${var.cluster_name}.${data.google_dns_managed_zone.dns_zone[0].dns_name}"
  managed_zone = data.google_dns_managed_zone.dns_zone[0].name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_instance.nomad_clients[0].network_interface[0].access_config[0].nat_ip]
}

resource "google_dns_record_set" "consul" {
  count        = var.dns_zone_name != "" ? 1 : 0
  name         = "consul-${var.cluster_name}.${data.google_dns_managed_zone.dns_zone[0].dns_name}"
  managed_zone = data.google_dns_managed_zone.dns_zone[0].name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_instance.nomad_servers[0].network_interface[0].access_config[0].nat_ip]
}

resource "google_dns_record_set" "nomad" {
  count        = var.dns_zone_name != "" ? 1 : 0
  name         = "nomad-${var.cluster_name}.${data.google_dns_managed_zone.dns_zone[0].dns_name}"
  managed_zone = data.google_dns_managed_zone.dns_zone[0].name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_instance.nomad_servers[0].network_interface[0].access_config[0].nat_ip]
}

resource "google_dns_record_set" "grafana" {
  count        = var.dns_zone_name != "" ? 1 : 0
  name         = "grafana-${var.cluster_name}.${data.google_dns_managed_zone.dns_zone[0].dns_name}"
  managed_zone = data.google_dns_managed_zone.dns_zone[0].name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_instance.nomad_clients[1].network_interface[0].access_config[0].nat_ip]
}

resource "google_dns_record_set" "prometheus" {
  count        = var.dns_zone_name != "" ? 1 : 0
  name         = "prometheus-${var.cluster_name}.${data.google_dns_managed_zone.dns_zone[0].dns_name}"
  managed_zone = data.google_dns_managed_zone.dns_zone[0].name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_instance.nomad_clients[0].network_interface[0].access_config[0].nat_ip]
}

# Static IP for load balancer
resource "google_compute_global_address" "hashistack_lb_ip" {
  name = "hashistack-lb-ip"
}

# Health check for Traefik instances
resource "google_compute_health_check" "traefik_health" {
  name               = "traefik-health-check"
  check_interval_sec = 5
  timeout_sec        = 5
  healthy_threshold  = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 8080
    request_path = "/ping"
  }
}

# Instance group for Nomad clients (where apps run)
resource "google_compute_instance_group" "nomad_clients" {
  name = "nomad-clients-group"
  zone = var.zone

  instances = google_compute_instance.nomad_clients[*].id

  named_port {
    name = "http"
    port = 80
  }

  named_port {
    name = "traefik-api"
    port = 8080
  }
}

# Backend service for Terramino app
resource "google_compute_backend_service" "terramino" {
  name                  = "terramino-backend"
  protocol              = "HTTP"
  timeout_sec           = 30
  enable_cdn           = false
  load_balancing_scheme = "EXTERNAL"

  backend {
    group                 = google_compute_instance_group.nomad_clients.id
    balancing_mode        = "UTILIZATION"
    capacity_scaler       = 1.0
    max_utilization       = 0.8
  }

  health_checks = [google_compute_health_check.traefik_health.id]
}

# Backend service for Grafana
resource "google_compute_backend_service" "grafana" {
  name                  = "grafana-backend"
  protocol              = "HTTP"
  timeout_sec           = 30
  enable_cdn           = false
  load_balancing_scheme = "EXTERNAL"

  backend {
    group                 = google_compute_instance_group.nomad_clients.id
    balancing_mode        = "UTILIZATION"
    capacity_scaler       = 1.0
    max_utilization       = 0.8
  }

  health_checks = [google_compute_health_check.traefik_health.id]
}

# Backend service for Prometheus
resource "google_compute_backend_service" "prometheus" {
  name                  = "prometheus-backend"
  protocol              = "HTTP"
  timeout_sec           = 30
  enable_cdn           = false
  load_balancing_scheme = "EXTERNAL"

  backend {
    group                 = google_compute_instance_group.nomad_clients.id
    balancing_mode        = "UTILIZATION"
    capacity_scaler       = 1.0
    max_utilization       = 0.8
  }

  health_checks = [google_compute_health_check.traefik_health.id]
}

# URL map for routing
resource "google_compute_url_map" "hashistack_lb" {
  name            = "hashistack-lb-url-map"
  default_service = google_compute_backend_service.terramino.id

  host_rule {
    hosts        = ["terramino-${var.cluster_name}.${var.domain_name}"]
    path_matcher = "terramino"
  }

  host_rule {
    hosts        = ["grafana-${var.cluster_name}.${var.domain_name}"]
    path_matcher = "grafana"
  }

  host_rule {
    hosts        = ["prometheus-${var.cluster_name}.${var.domain_name}"]
    path_matcher = "prometheus"
  }

  path_matcher {
    name            = "terramino"
    default_service = google_compute_backend_service.terramino.id
  }

  path_matcher {
    name            = "grafana"
    default_service = google_compute_backend_service.grafana.id
  }

  path_matcher {
    name            = "prometheus"
    default_service = google_compute_backend_service.prometheus.id
  }
}

# HTTP(S) proxy
resource "google_compute_target_http_proxy" "hashistack_lb" {
  name    = "hashistack-lb-target-proxy"
  url_map = google_compute_url_map.hashistack_lb.id
}

# Global forwarding rule
resource "google_compute_global_forwarding_rule" "hashistack_lb" {
  name       = "hashistack-lb-forwarding-rule"
  target     = google_compute_target_http_proxy.hashistack_lb.id
  port_range = "80"
  ip_address = google_compute_global_address.hashistack_lb_ip.address
}

# SSL certificate (optional - uncomment if you have a domain)
# resource "google_compute_managed_ssl_certificate" "hashistack_ssl" {
#   name = "hashistack-ssl-cert"
#
#   managed {
#     domains = [
#       "terramino-${var.cluster_name}.${var.domain_name}",
#       "grafana-${var.cluster_name}.${var.domain_name}",
#       "prometheus-${var.cluster_name}.${var.domain_name}"
#     ]
#   }
# }

# HTTPS proxy (optional - uncomment if using SSL)
# resource "google_compute_target_https_proxy" "hashistack_lb_https" {
#   name             = "hashistack-lb-target-https-proxy"
#   url_map          = google_compute_url_map.hashistack_lb.id
#   ssl_certificates = [google_compute_managed_ssl_certificate.hashistack_ssl.id]
# }

# HTTPS forwarding rule (optional - uncomment if using SSL)
# resource "google_compute_global_forwarding_rule" "hashistack_lb_https" {
#   name       = "hashistack-lb-https-forwarding-rule"
#   target     = google_compute_target_https_proxy.hashistack_lb_https.id
#   port_range = "443"
#   ip_address = google_compute_global_address.hashistack_lb_ip.address
# }

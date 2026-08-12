output "proxy_instance_name" {
  description = "Name of transparent proxy Compute Engine instance"
  value       = google_compute_instance.transparent_proxy.name
}

output "proxy_instance_self_link" {
  description = "Self link of transparent proxy Compute Engine instance"
  value       = google_compute_instance.transparent_proxy.self_link
}

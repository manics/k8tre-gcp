variable "name" {
  type        = string
  description = "DNS zone domain name (without trailing dot)"
}

variable "vpc" {
  type        = string
  description = "VPC network self link or ID"
}

variable "enable_inbound_forwarding" {
  type        = bool
  default     = true
  description = "Enable Cloud DNS inbound forwarding for the VPC"
}

variable "enable_logging" {
  type        = bool
  default     = true
  description = "Enable Cloud DNS query logging for the VPC"
}

variable "static-ttl" {
  type        = number
  description = "TTL for static entries"
  default     = 3600
}

variable "static" {
  type        = list(any)
  description = "List of lists of records [ [name, type, ip], [name, type, ip] ]"
  default     = []
}

variable "create_public_zone" {
  type        = bool
  default     = true
  description = "Create a public zone with the same name as the private zone"
}

variable "public-records" {
  type        = map(list(string))
  description = <<EOF
    "map of {'<name> <type>' => [destinations]}"
    e.g.
      "dev-a A" = ["192.0.2.3"]
      "dev-cname CNAME" = ["foo.example.org."]
  EOF
  default     = {}
}

variable "private-records" {
  type        = map(list(string))
  description = <<EOF
    "map of {'<name> <type>' => [destinations]}"
    e.g.
      "dev-a A" = ["192.0.2.3"]
      "dev-cname CNAME" = ["foo.example.org."]
  EOF
  default     = {}
}

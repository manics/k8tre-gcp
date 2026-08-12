variable "name" {
  type        = string
  description = "zone name"
}

variable "vpc" {
  type        = string
  description = "VPC network self link or ID"
}

# tflint-ignore: terraform_unused_declarations
variable "name_tag" {
  type        = string
  description = "Name used for private resources"
  default     = "private"
}

# tflint-ignore: terraform_unused_declarations
variable "allow_dns_from_cidrs" {
  type        = list(any)
  description = "List of cidrs to allow private zone dns from"
  default     = ["10.0.0.0/8"]
}

variable "static-ttl" {
  type        = number
  description = "ttl for static entries"
  default     = 3600
}

variable "static" {
  type        = list(any)
  description = "list of lists of records [ [name, type, ip], [name, type, ip] ]"
  default     = []
}

# tflint-ignore: terraform_unused_declarations
variable "alarm_topics" {
  type        = list(string)
  description = "Alerting topics"
  default     = []
}

# tflint-ignore: terraform_unused_declarations
variable "allowed_domains" {
  type        = list(string)
  description = "List of allowed private zone DNS lookup domains"
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
      "dev-cname CNAME" = ["foo.example.org"]
  EOF
  default     = {}
}

variable "private-records" {
  type        = map(list(string))
  description = <<EOF
    "map of {'<name> <type>' => [destinations]}"
    e.g.
      "dev-a A" = ["192.0.2.3"]
      "dev-cname CNAME" = ["foo.example.org"]
  EOF
  default     = {}
}


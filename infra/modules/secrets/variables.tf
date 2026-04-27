variable "env" {
  type = string
}

variable "secrets" {
  type = map(object({
    description = optional(string)
    # If `value` is null, a random 32-char string is generated.
    value = optional(string)
  }))
  description = <<EOT
Map of AWS Secrets Manager secrets to provision. Keys become the secret
suffix; the resulting full name is "$${var.env}/<key>". The pattern mirrors
/Users/crewmaty/infra/modules/services/main.tf (mariadb / influx / mongo
secrets) but is generalized so callers can pass arbitrary key/value pairs.
EOT
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}

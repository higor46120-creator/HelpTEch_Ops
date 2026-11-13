# HTTPS - HelpTech AWS EKS
# Preparacao: ainda nao ativa recursos AWS.

variable "enable_https" {
  description = "Habilitar HTTPS quando a infraestrutura estiver pronta"
  type        = bool
  default     = false
}

variable "app_domain" {
  description = "Dominio publico do HelpTech"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ARN do certificado TLS no AWS Certificate Manager"
  type        = string
  default     = ""
}

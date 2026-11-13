variable "eks_api_allowed_cidrs" {
  description = "IPs autorizados a acessar a API publica do EKS"
  type        = list(string)
}

variable "cluster_name" {
  description = "Nome do cluster Minikube"
  type        = string
  default     = "minikube-custom"
}

variable "kubernetes_version" {
  description = "Versao do Kubernetes a ser instalada no cluster"
  type        = string
  default     = "v1.30.0"
}

variable "driver" {
  description = "Driver de virtualização/container"
  type        = string
  default     = "docker"
}

variable "container_runtime" {
  description = "Runtime de container dentro do cluster"
  type        = string
  default     = "containerd"
}

variable "memory" {
  description = "Quantidade de memória RAM alocada"
  type        = string
  default     = "4000mb"
}

variable "cpus" {
  description = "Quantidade de CPUs alocadas para o cluster"
  type        = number
  default     = 2
}

variable "nodes" {
  description = "Quantidade de nós no cluster"
  type        = number
  default     = 1
}

variable "cni" {
  description = "Network Plugin (CNI)"
  type        = string
  default     = "flannel"
}

variable "base_image" {
  description = "Imagem base (kicbase) compatível"
  type        = string
  default     = "gcr.io/k8s-minikube/kicbase:v0.0.44"
}

variable "addons" {
  description = "Lista de addons a serem habilitados no Minikube"
  type        = list(string)
  default = [
    "metrics-server",
    "dashboard",
    "default-storageclass",
    "storage-provisioner"
  ]
}

output "cluster_name" {
  description = "Nome do cluster criado"
  value       = minikube_cluster.custom.cluster_name
}

output "cluster_host" {
  description = "Endereço Host da API do Kubernetes"
  value       = minikube_cluster.custom.host
}

output "enabled_addons" {
  description = "Addons ativados no cluster"
  value       = minikube_cluster.custom.addons
}

output "output_file_location" {
  description = "Caminho do arquivo com os dados do cluster"
  value       = local_file.outputs_file.filename
}

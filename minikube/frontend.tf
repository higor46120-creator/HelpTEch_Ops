resource "null_resource" "apply_k8s_frontend" {
  triggers = {
    always_run      = timestamp()
    deployment_hash = filesha256("${path.module}/terraform/scripts/k8s/frontend/deployment.yaml")
    cluster_name    = minikube_cluster.custom.cluster_name
  }

  depends_on = [
    minikube_cluster.custom
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail

      echo "===================================="
      echo " HelpTech - Frontend"
      echo "===================================="

      FRONTEND_DIR="$HOME/Desktop/TCC/projeto-frontend"

      echo "Construindo imagem Docker..."
      docker build -t helptech-frontend:teste "$FRONTEND_DIR"

      echo "Carregando imagem no Minikube..."
      minikube -p "${minikube_cluster.custom.cluster_name}" image load --overwrite=true helptech-frontend:teste

      echo "Aplicando frontend no Kubernetes..."
      minikube -p "${minikube_cluster.custom.cluster_name}" kubectl -- apply -f "${path.module}/terraform/scripts/k8s/frontend/deployment.yaml"

      echo "Atualizando o Deployment..."
      minikube -p "${minikube_cluster.custom.cluster_name}" kubectl -- rollout restart deployment/frontend-deployment

      echo "Aguardando frontend ficar pronto..."
      minikube -p "${minikube_cluster.custom.cluster_name}" kubectl -- rollout status deployment/frontend-deployment --timeout=180s

      echo "Frontend implantado com sucesso!"
    EOT

    interpreter = [
      "C:/Program Files/Git/bin/bash.exe",
      "-c"
    ]
  }
}

resource "minikube_cluster" "custom" {
  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  driver             = var.driver
  container_runtime  = var.container_runtime
  memory             = var.memory
  cpus               = var.cpus
  nodes              = var.nodes
  cni                = var.cni
  base_image         = var.base_image
  addons             = var.addons
}

resource "local_file" "outputs_file" {
  filename = "${path.module}/cluster_outputs.json"

  content = jsonencode({
    cluster_name           = minikube_cluster.custom.cluster_name
    kubernetes_version     = minikube_cluster.custom.kubernetes_version
    driver                 = minikube_cluster.custom.driver
    container_runtime      = minikube_cluster.custom.container_runtime
    memory                 = minikube_cluster.custom.memory
    cpus                   = minikube_cluster.custom.cpus
    nodes                  = minikube_cluster.custom.nodes
    cni                    = minikube_cluster.custom.cni
    base_image             = minikube_cluster.custom.base_image
    addons                 = minikube_cluster.custom.addons
    host                   = minikube_cluster.custom.host
    client_certificate     = minikube_cluster.custom.client_certificate
    client_key             = minikube_cluster.custom.client_key
    cluster_ca_certificate = minikube_cluster.custom.cluster_ca_certificate
  })
}

resource "null_resource" "apply_k8s_backend" {
  triggers = {
    always_run      = timestamp()
    script_hash     = filesha256("${path.module}/terraform/scripts/apply-k8s.sh")
    deployment_hash = filesha256("${path.module}/terraform/scripts/k8s/backend/deployment.yaml")
    cluster_name    = minikube_cluster.custom.cluster_name
  }

  depends_on = [
    minikube_cluster.custom
  ]

  provisioner "local-exec" {
    command = "bash ${path.module}/terraform/scripts/apply-k8s.sh ${minikube_cluster.custom.cluster_name}"

    interpreter = [
      "C:/Program Files/Git/bin/bash.exe",
      "-c"
    ]

    environment = {
      SERVICE_ACCOUNT_FILE = "/c/Users/46120/Documents/serviceAccountKey.json"
    }
  }
}


# Exposição do Serviço e Redirecionamento de Porta (Port-Forward)

resource "null_resource" "expose_service" {
  depends_on = [null_resource.apply_k8s_backend]

  triggers = {
    deployment_hash = filemd5("${path.module}/terraform/scripts/k8s/backend/deployment.yaml")
  }

  # Executado no 'terraform apply'
  provisioner "local-exec" {
    command     = <<EOT
      echo "⏳ Aguardando o Deployment e os Pods ficarem 100% Ready..."
      kubectl rollout status deployment/backend-deployment --timeout=180s
      kubectl wait --for=condition=Ready pod -l app=backend --timeout=180s

      echo "🚀 Pods prontos! Iniciando o port-forward em background..."
      nohup kubectl port-forward service/backend-service --address 0.0.0.0 8080:8080 > /dev/null 2>&1 &
    EOT
    interpreter = ["bash", "-c"]
  }

  # Executado no 'terraform destroy'
  provisioner "local-exec" {
    when        = destroy
    command     = "pkill -f 'kubectl port-forward service/backend-service --address 0.0.0.0 8080:8080' || true"
    interpreter = ["bash", "-c"]
  }
}

output "swagger_url" {
  description = "URL local do Swagger UI"
  value       = "http://127.0.0.1:8080/swagger-ui/index.html"
}
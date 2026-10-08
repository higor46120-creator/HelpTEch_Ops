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

resource "null_resource" "swagger_port_forward" {
  triggers = {
    always_run = timestamp()
  }

  depends_on = [
    null_resource.apply_k8s_backend
  ]

  provisioner "local-exec" {
    command = <<-EOT
      $existing = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue

      if (-not $existing) {
        Start-Process `
          -FilePath "minikube" `
          -ArgumentList "-p","${minikube_cluster.custom.cluster_name}","kubectl","--","port-forward","service/backend-service","8080:8080","--namespace=default" `
          -WindowStyle Hidden

        Start-Sleep -Seconds 5
      }

      try {
        $response = Invoke-WebRequest `
          -Uri "http://127.0.0.1:8080/actuator/health" `
          -UseBasicParsing `
          -TimeoutSec 10

        if ($response.StatusCode -ne 200) {
          throw "Backend não respondeu HTTP 200."
        }

        Write-Host ""
        Write-Host "===================================="
        Write-Host " Swagger disponível!"
        Write-Host " http://127.0.0.1:8080/swagger-ui/index.html"
        Write-Host "===================================="

        Start-Process "http://127.0.0.1:8080/swagger-ui/index.html"
      }
      catch {
        Write-Error "Não foi possível acessar o backend pela porta 8080."
        exit 1
      }
    EOT

    interpreter = [
      "PowerShell",
      "-NoProfile",
      "-Command"
    ]
  }
}

output "swagger_url" {
  description = "URL local do Swagger UI"
  value       = "http://127.0.0.1:8080/swagger-ui/index.html"
}
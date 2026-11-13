# --------------------------------------------------
# DEPLOY DAS APLICAÇÕES VIA SCRIPTS + MANIFESTOS YAML (scripts/k8s)
# Mesmo modelo do projeto Minikube: null_resource + local-exec + kubectl
# --------------------------------------------------

locals {
  # Variáveis comuns a todos os scripts (sem valores sensíveis, para não
  # esconder o log do local-exec)
  k8s_env = {
    CLUSTER_NAME = module.eks.cluster_name
    AWS_REGION   = var.aws_region
    NAMESPACE    = var.namespace
    KUBECONFIG   = ".kube/config"
  }

  firebase_file_hash = (
    fileexists("${path.module}/${var.firebase_credentials_file}")
    ? filemd5("${path.module}/${var.firebase_credentials_file}")
    : "arquivo-ausente"
  )
}

# 1. Segredos para o script do backend, em base64 (arquivo local, ignorado pelo git)
resource "local_sensitive_file" "deploy_secrets" {
  filename        = "${path.module}/.deploy-secrets.env"
  file_permission = "0600"
  content         = <<-EOT
    DB_USER_B64=${base64encode(var.db_username)}
    DB_PASSWORD_B64=${base64encode(random_password.db.result)}
    GOOGLE_CLIENT_ID_B64=${var.google_client_id != "" ? base64encode(var.google_client_id) : ""}
    GOOGLE_CLIENT_SECRET_B64=${var.google_client_secret != "" ? base64encode(var.google_client_secret) : ""}
    JWT_SECRET_B64=${var.jwt_secret != "" ? base64encode(var.jwt_secret) : ""}
  EOT
}

# 2. Namespace — no destroy remove tudo (inclusive os Load Balancers da AWS)
resource "null_resource" "k8s_namespace" {
  # Só muda se o cluster mudar: alterar YAMLs nunca apaga o namespace
  triggers = {
    cluster_name = module.eks.cluster_name
    aws_region   = var.aws_region
    namespace    = var.namespace
    bash_path    = var.bash_path
    working_dir  = path.module
  }

  depends_on = [module.eks]

  provisioner "local-exec" {
    interpreter = [var.bash_path, "-c"]
    working_dir = path.module
    environment = local.k8s_env
    command     = "./scripts/namespace.sh apply"
  }

  # Equivalente ao 'taskkill kubectl' do projeto anterior: limpa antes do destroy
  provisioner "local-exec" {
    when        = destroy
    interpreter = [self.triggers.bash_path, "-c"]
    working_dir = self.triggers.working_dir
    environment = {
      CLUSTER_NAME = self.triggers.cluster_name
      AWS_REGION   = self.triggers.aws_region
      NAMESPACE    = self.triggers.namespace
      KUBECONFIG   = ".kube/config"
    }
    command = "./scripts/namespace.sh delete"
  }
}

# 3. Frontend (vem primeiro: o backend usa a URL dele no redirect do OAuth2)
resource "null_resource" "k8s_frontend_deploy" {
  triggers = {
    common_script   = filemd5("${path.module}/scripts/common.sh")
    deploy_script   = filemd5("${path.module}/scripts/deploy-frontend.sh")
    manifest        = filemd5("${path.module}/scripts/k8s/frontend/deployment.yaml")
    image           = var.frontend_image
    service_type    = var.enable_https ? "ClusterIP" : "LoadBalancer"
    namespace_reset = null_resource.k8s_namespace.id
  }

  provisioner "local-exec" {
    interpreter = [var.bash_path, "-c"]
    working_dir = path.module
    environment = merge(local.k8s_env, {
      FRONTEND_IMAGE        = var.frontend_image
      FRONTEND_SERVICE_TYPE = var.enable_https ? "ClusterIP" : "LoadBalancer"
    })
    command = "./scripts/deploy-frontend.sh"
  }
}

# 4. Backend (após RDS, metrics-server e frontend)
resource "null_resource" "k8s_backend_deploy" {
  triggers = {
    common_script   = filemd5("${path.module}/scripts/common.sh")
    deploy_script   = filemd5("${path.module}/scripts/deploy-backend.sh")
    configmap       = filemd5("${path.module}/scripts/k8s/backend/configmap.yaml")
    secret          = filemd5("${path.module}/scripts/k8s/backend/secret.yaml")
    manifest        = filemd5("${path.module}/scripts/k8s/backend/deployment.yaml")
    image           = var.backend_image
    db_host         = aws_db_instance.mysql.address
    secrets_hash    = local_sensitive_file.deploy_secrets.content_sha256
    firebase_hash   = local.firebase_file_hash
    oauth2_redirect = var.frontend_oauth2_redirect_uri
    namespace_reset = null_resource.k8s_namespace.id
  }

  depends_on = [
    null_resource.k8s_frontend_deploy,
    helm_release.metrics_server,
    aws_vpc_security_group_ingress_rule.rds_from_nodes,
    aws_vpc_security_group_ingress_rule.rds_from_cluster,
  ]

  provisioner "local-exec" {
    interpreter = [var.bash_path, "-c"]
    working_dir = path.module
    environment = merge(local.k8s_env, {
      BACKEND_IMAGE                = var.backend_image
      DB_HOST                      = aws_db_instance.mysql.address
      DB_PORT                      = tostring(aws_db_instance.mysql.port)
      DB_NAME                      = var.db_name
      SECRETS_FILE                 = basename(local_sensitive_file.deploy_secrets.filename)
      FIREBASE_CREDENTIALS_FILE    = var.firebase_credentials_file
      FRONTEND_OAUTH2_REDIRECT_URI = var.frontend_oauth2_redirect_uri
    })
    command = "./scripts/deploy-backend.sh"
  }
}

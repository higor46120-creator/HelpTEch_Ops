#!/usr/bin/env bash
# --------------------------------------------------
# DEPLOY DO BACKEND
# Variáveis extras (passadas pelo Terraform):
#   BACKEND_IMAGE, DB_HOST, DB_PORT, SECRETS_FILE, FIREBASE_CREDENTIALS_FILE,
#   FRONTEND_OAUTH2_REDIRECT_URI (opcional)
# --------------------------------------------------
source "$(dirname "$0")/common.sh"

: "${BACKEND_IMAGE:?BACKEND_IMAGE não definido}"
: "${DB_HOST:?DB_HOST não definido}"
: "${DB_PORT:=3306}"
: "${SECRETS_FILE:=.deploy-secrets.env}"
: "${FIREBASE_CREDENTIALS_FILE:=serviceAccountKey.json}"
: "${DB_NAME:?DB_NAME nao definido}"
export BACKEND_IMAGE DB_HOST DB_PORT DB_NAME

setup_kubeconfig

# --------------------------------------------------
# CREDENCIAIS
# --------------------------------------------------
if [ ! -f "${FIREBASE_CREDENTIALS_FILE}" ]; then
  echo "❌ Erro: Arquivo ${FIREBASE_CREDENTIALS_FILE} não encontrado na pasta terraform-eks."
  exit 1
fi

echo "🔐 Convertendo credenciais do Firebase para Base64..."
export FIREBASE_CREDENTIALS_BASE64=$(base64 -w 0 "${FIREBASE_CREDENTIALS_FILE}")

# Senha do RDS e segredos opcionais, já em base64, gerados pelo Terraform
set -a
source "${SECRETS_FILE}"
if [ -f .deploy-oauth.env ]; then source .deploy-oauth.env; fi
set +a

# --------------------------------------------------
# REDIRECT DO OAUTH2 (padrão: URL do Load Balancer do frontend)
# --------------------------------------------------
if [ -z "${FRONTEND_OAUTH2_REDIRECT_URI:-}" ]; then
  FRONTEND_HOST=$(wait_lb_hostname frontend-service)
  FRONTEND_OAUTH2_REDIRECT_URI="http://${FRONTEND_HOST}/oauth2/redirect"
fi
export FRONTEND_OAUTH2_REDIRECT_URI
echo "📌 Banco: ${DB_HOST}:${DB_PORT} | OAuth2 redirect: ${FRONTEND_OAUTH2_REDIRECT_URI}"

# --------------------------------------------------
# RENDERIZA OS MANIFESTOS
# --------------------------------------------------
CONFIG_YAML=$(envsubst '${DB_HOST} ${DB_PORT} ${DB_NAME} ${FRONTEND_OAUTH2_REDIRECT_URI}' < scripts/k8s/backend/configmap.yaml)
SECRET_YAML=$(envsubst '${FIREBASE_CREDENTIALS_BASE64} ${DB_USER_B64} ${DB_PASSWORD_B64}' < scripts/k8s/backend/secret.yaml)

# Secret opcional: só inclui as chaves que foram informadas
OPTIONAL_ARGS=()
for key in GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET JWT_SECRET; do
  b64_var="${key}_B64"
  if [ -n "${!b64_var:-}" ]; then
    OPTIONAL_ARGS+=("--from-literal=${key}=$(printf '%s' "${!b64_var}" | base64 -d)")
  fi
done
OPTIONAL_YAML=""
if [ ${#OPTIONAL_ARGS[@]} -gt 0 ]; then
  OPTIONAL_YAML=$(k create secret generic backend-optional-secret "${OPTIONAL_ARGS[@]}" --dry-run=client -o yaml)
fi

# Hash da configuração -> annotation do pod (reinicia os pods quando algo muda)
export CONFIG_HASH=$(printf '%s' "${CONFIG_YAML}${SECRET_YAML}${OPTIONAL_YAML}" | sha256sum | cut -c1-16)

# --------------------------------------------------
# APLICA NO CLUSTER
# --------------------------------------------------
echo "🚀 Aplicando manifestos do Backend..."
printf '%s\n' "${CONFIG_YAML}"   | k apply -f -
printf '%s\n' "${SECRET_YAML}"   | k apply -f -
if [ -n "${OPTIONAL_YAML}" ]; then
  printf '%s\n' "${OPTIONAL_YAML}" | k apply -f -
fi
envsubst '${BACKEND_IMAGE} ${CONFIG_HASH}' < scripts/k8s/backend/deployment.yaml | k apply -f -

echo "⏳ Aguardando o Backend ficar 100% Ready..."
k rollout status deployment/backend-deployment --timeout=600s


echo "Backend interno disponivel: http://backend-service.${NAMESPACE}.svc.cluster.local:8080"

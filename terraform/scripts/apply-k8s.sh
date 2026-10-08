#!/usr/bin/env bash

set -euo pipefail

# --------------------------------------------------
# CLUSTER MINIKUBE
# --------------------------------------------------

# Recebe o nome do cluster pelo Terraform.
# Caso não seja informado, usa minikube-custom.
CLUSTER_NAME=${1:-"minikube-custom"}

# Habilita aliases dentro do script Bash
shopt -s expand_aliases

# Kubectl sempre direcionado ao cluster correto
alias k="minikube -p ${CLUSTER_NAME} kubectl --"

echo "===================================="
echo " Kubernetes - HelpTech Backend"
echo " Cluster: ${CLUSTER_NAME}"
echo "===================================="

# --------------------------------------------------
# GARANTE QUE O CLUSTER ESTEJA RODANDO
# --------------------------------------------------

echo
echo "Verificando cluster Minikube..."

CLUSTER_STATUS=$(
    minikube -p "$CLUSTER_NAME" status \
        --format='{{.Host}}' 2>/dev/null \
        || true
)

if [ "$CLUSTER_STATUS" != "Running" ]; then
    echo "Cluster parado. Iniciando ${CLUSTER_NAME}..."

    minikube start -p "$CLUSTER_NAME"
else
    echo "Cluster ${CLUSTER_NAME} já está rodando."
fi

echo "Cluster disponível."

# --------------------------------------------------
# AGUARDA O NÓ KUBERNETES
# --------------------------------------------------

echo
echo "Aguardando nó Kubernetes ficar Ready..."

k wait \
    --for=condition=Ready \
    node \
    --all \
    --timeout=180s

echo "Nó Kubernetes está Ready."

# --------------------------------------------------
# CAMINHOS
# --------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/k8s/backend"

DEPLOYMENT_FILE="$BACKEND_DIR/deployment.yaml"
SECRET_FILE="$BACKEND_DIR/secrets.yaml"

NAMESPACE="default"
SECRET_NAME="firebase-secret"

# --------------------------------------------------
# VALIDAÇÕES
# --------------------------------------------------

if [ ! -f "$DEPLOYMENT_FILE" ]; then
    echo "ERRO: deployment.yaml não encontrado:"
    echo "$DEPLOYMENT_FILE"
    exit 1
fi

if [ -z "${SERVICE_ACCOUNT_FILE:-}" ]; then
    echo "ERRO: SERVICE_ACCOUNT_FILE não foi informado."
    exit 1
fi

if [ ! -f "$SERVICE_ACCOUNT_FILE" ]; then
    echo "ERRO: serviceAccountKey.json não encontrado em:"
    echo "$SERVICE_ACCOUNT_FILE"
    exit 1
fi

# --------------------------------------------------
# OBTÉM O IP DO HOST
# Compatível com Windows / Git Bash
# --------------------------------------------------

echo
echo "Obtendo o IP do host para resolução de DNS..."

HOST_IP=$(
    minikube -p "$CLUSTER_NAME" ssh \
        "getent hosts host.minikube.internal" 2>/dev/null \
        | awk '{print $1}' \
        | tr -d '\r' \
        || true
)

# Fallback caso a resolução automática falhe
if [ -z "$HOST_IP" ]; then
    HOST_IP="172.17.0.1"
fi

export HOST_IP

echo "IP do Host detectado: ${HOST_IP}"

# --------------------------------------------------
# FIREBASE SECRET
# --------------------------------------------------

echo
echo "[1/4] Gerando secrets.yaml..."

k create secret generic "$SECRET_NAME" \
    --from-file=FIREBASE_CREDENTIALS_JSON="$SERVICE_ACCOUNT_FILE" \
    --namespace="$NAMESPACE" \
    --dry-run=client \
    -o yaml > "$SECRET_FILE"

echo "Secret gerado."

echo
echo "[2/4] Aplicando Secret..."

k apply -f "$SECRET_FILE"

# --------------------------------------------------
# DEPLOYMENT BACKEND
# --------------------------------------------------

echo
echo "[3/4] Aplicando Deployment..."

# Substitui ${HOST_IP} pelo IP obtido dinamicamente
# antes de enviar o manifesto para o Kubernetes.
sed "s|\${HOST_IP}|${HOST_IP}|g" "$DEPLOYMENT_FILE" | k apply -f -

# --------------------------------------------------
# ROLLOUT
# --------------------------------------------------

echo
echo "[4/4] Aguardando rollout do backend..."

k rollout status deployment/backend-deployment \
    --namespace="$NAMESPACE" \
    --timeout=180s

# --------------------------------------------------
# AGUARDA O POD FICAR READY
# --------------------------------------------------

echo
echo "Aguardando pod do backend ficar Ready..."

k wait \
    --for=condition=Ready \
    pod \
    -l app=backend \
    --namespace="$NAMESPACE" \
    --timeout=180s

# --------------------------------------------------
# RESULTADO
# --------------------------------------------------

echo
echo "===================================="
echo " Backend aplicado com sucesso!"
echo "===================================="

echo
echo "Pods:"

k get pods \
    --namespace="$NAMESPACE" \
    -l app=backend

echo
echo "Service:"

k get service backend-service \
    --namespace="$NAMESPACE"
#!/usr/bin/env bash
# --------------------------------------------------
# DEPLOY DO FRONTEND
# Variáveis extras: FRONTEND_IMAGE
# --------------------------------------------------
source "$(dirname "$0")/common.sh"

: "${FRONTEND_IMAGE:?FRONTEND_IMAGE não definido}"
: "${FRONTEND_SERVICE_TYPE:=LoadBalancer}"
export FRONTEND_IMAGE FRONTEND_SERVICE_TYPE

setup_kubeconfig

echo "🚀 Aplicando manifestos do Frontend..."
envsubst '${FRONTEND_IMAGE} ${FRONTEND_SERVICE_TYPE}' < scripts/k8s/frontend/deployment.yaml | k apply -f -

echo "⏳ Aguardando o Frontend ficar 100% Ready..."
k rollout status deployment/frontend-deployment --timeout=300s

FRONTEND_HOST=$(wait_lb_hostname frontend-service)

echo "✅ Frontend disponível em: http://${FRONTEND_HOST}"
echo "   (o DNS do Load Balancer pode levar 1–2 minutos para propagar)"

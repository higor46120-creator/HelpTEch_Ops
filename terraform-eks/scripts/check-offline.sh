#!/usr/bin/env bash

set -u
cd "$(dirname "$0")/.." || exit 1

falhas=0

echo "===== HELPTECH - AWS EKS ====="

echo "=== TERRAFORM ==="
terraform validate || falhas=$((falhas + 1))
terraform fmt -check -recursive || falhas=$((falhas + 1))

echo "=== SCRIPTS BASH ==="
for arquivo in scripts/*.sh; do
    bash -n "$arquivo" || falhas=$((falhas + 1))
done

echo "=== DOCKER ==="
if docker info >/dev/null 2>&1; then
    for imagem in \
        higorsantanafiec/helptech-backend:aws-v1 \
        higorsantanafiec/helptech-frontend:aws-v1 \
        higorsantanafiec/helptech-frontend:aws-v2-nginx
    do
        if docker image inspect "$imagem" >/dev/null 2>&1; then
            echo "OK: $imagem"
        else
            echo "AVISO: imagem nao encontrada: $imagem"
        fi
    done
else
    echo "AVISO: Docker indisponivel."
fi

echo "=== RESULTADO ==="
echo "Falhas de validacao: $falhas"

exit "$falhas"

resource "null_resource" "expose_frontend" {
  depends_on = [
    null_resource.apply_k8s_frontend
  ]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail

      echo "Verificando acesso ao frontend..."

      if curl -fsS --max-time 2 http://127.0.0.1:8081/ > /dev/null 2>&1; then
        echo "Porta 8081 já está respondendo."
      else
        echo "Iniciando port-forward do frontend..."

        nohup kubectl port-forward \
          --address 127.0.0.1 \
          service/frontend-service \
          8081:80 > /dev/null 2>&1 &
      fi

      echo "Aguardando frontend responder..."

      for i in $(seq 1 30); do
        if curl -fsS --max-time 2 http://127.0.0.1:8081/ > /dev/null 2>&1; then
          echo "Frontend disponível em http://127.0.0.1:8081/"
          powershell.exe -NoProfile -Command "Start-Process 'http://127.0.0.1:8081/'"
          exit 0
        fi
        sleep 1
      done

      echo "ERRO: frontend não respondeu na porta 8081."
      exit 1
    EOT

    interpreter = [
      "C:/Program Files/Git/bin/bash.exe",
      "-c"
    ]
  }
}

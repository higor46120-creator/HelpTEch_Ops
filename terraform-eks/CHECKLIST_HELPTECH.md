# Checklist de adaptação — HelpTech (infraestrutura independente)

## Já adaptado neste pacote

- EKS: `helptech-eks` (não utiliza nem altera `fieclab-eks`).
- Namespace: `helptech`; recursos Kubernetes com nomes de backend/frontend HelpTech.
- RDS MySQL: schema `helptec`, usuário `helptech`, endpoint privado, VPC própria.
- Terraform: região `us-east-1`, tags `HelpTech`, diretório e state próprios.
- Frontend: Vite com `VITE_API_URL` definido **durante o build**; não usar `REACT_APP_API_URL`.
- Credenciais e state do projeto de referência excluídos deste pacote.

## Confirmar no repositório real antes de aplicar

1. **Identidade AWS**: usar perfil IAM/função autorizada pelo professor, nunca a sessão `root` para criar recursos. Confirmar permissão e limite de custos. EKS, EC2, NAT Gateway, RDS e Load Balancers geram custos.
2. **Backend Docker**: definir imagem publicada em `backend_image`; validar o Dockerfile e os nomes reais das variáveis em `application.yaml` (`DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `FIREBASE_CREDENTIALS_JSON`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `JWT_SECRET`).
3. **Frontend Docker**: definir `frontend_image`; o Dockerfile precisa receber `ARG VITE_API_URL` e `ENV VITE_API_URL=$VITE_API_URL` antes do build. Rebuildar após conhecer a URL definitiva da API. Confirmar Nginx SPA fallback.
4. **Firebase**: fornecer somente a credencial do projeto HelpTech em arquivo local `serviceAccountKey.json`, nunca credencial do FiecLab. Não versionar.
5. **OAuth2 Google**: usar Client ID/Secret do HelpTech; definir URL de callback autorizada, domínio e HTTPS. Os Load Balancers HTTP do modelo não resolvem essa etapa automaticamente.
6. **Banco de dados**: validar esquema/migrações e URL JDBC. A configuração herdada de `rds.tf` permite conexões sem TLS (`require_secure_transport=0`) para compatibilidade com o backend do exemplo. Corrigir JDBC e exigir TLS antes de uso com dados reais.
7. **Persistência**: o exemplo contém `skip_final_snapshot=true` e `deletion_protection=false`; `terraform destroy` apagaria o RDS sem snapshot final. Rever política de backup e retenção antes de usar dados importantes.
8. **Deploy scripts**: conferir no Git Bash a existência de `aws`, `kubectl`, `terraform`, `envsubst`, `base64` e Docker. O caminho `bash_path` está configurado para Git Bash no Windows.
9. **Terraform**: executar apenas em `~/HelpTEch_Ops/terraform-eks` e conferir `terraform plan` antes de autorizar `apply`. Não copiar state do projeto do amigo.

## Passos locais seguros

No repositório `HelpTEch_Ops`, depois de colocar esta pasta como `terraform-eks`:

```bash
cd ~/HelpTEch_Ops/terraform-eks
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars com suas imagens e configurações (não publicar).
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

`terraform init` baixa plugins e módulos; `validate` não cria recursos AWS. **Não executar `terraform apply` antes de revisar custos, segurança, configuração da aplicação e autorização IAM.**

## O que NÃO fazer

- Não executar `terraform apply` ou `terraform destroy` na pasta do projeto FiecLab.
- Não reutilizar `terraform.tfstate`, `terraform.tfvars`, `serviceAccountKey.json`, OAuth ou JWT do colega.
- Não fazer commit/push de segredos ou arquivos `.tfstate`.
- Não executar mudanças de infraestrutura autenticado como `root`.

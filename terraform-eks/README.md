# HelpTech — infraestrutura AWS EKS independente (base adaptada)

Base adaptada do pacote de exemplo fornecido para a migração Minikube → AWS. **Esta pasta é um ponto de partida, não um deploy validado.** Nenhum recurso AWS foi criado.

**Importante:** o cluster existente `fieclab-eks` é somente uma referência do outro projeto. Esta configuração prevê criar **outro cluster**, `helptech-eks`, em uma VPC própria, com RDS próprio e namespace `helptech`. Não aplique Terraform no state/diretório do FiecLab.

Leia `CHECKLIST_HELPTECH.md` antes de iniciar.

## O que foi adaptado
- Cluster `helptech-eks`, namespace `helptech`, schema MySQL `helptec` e usuário `helptech`.
- Tags, scripts, nomes e exemplos passaram a referenciar HelpTech.
- Frontend Vite: variável de build **`VITE_API_URL`** (não `REACT_APP_API_URL`).
- Corrigido o caso de Secret OAuth opcional vazio no script de deploy.
- Credenciais e dados privados do projeto original **não estão incluídos**.
- `.gitignore` protege `terraform.tfvars`, `serviceAccountKey.json`, arquivos de state e segredos locais.

## Antes de qualquer `terraform apply`
1. Confirme autorização do responsável pela conta AWS e **custos** (EKS + EC2 + NAT + RDS + Load Balancers). O material de referência estima cerca de US$ 220/mês com uso contínuo, sem garantia de preço atual.
2. No Git Bash, valide acesso programático: `aws sts get-caller-identity`. **Estar logado no navegador não comprova acesso do CLI**. Evite credenciais root.
3. Use `cp terraform.tfvars.example terraform.tfvars` e configure as imagens Docker **reais, públicas ou acessíveis pelo EKS**, do HelpTech, com tags versionadas.
4. Insira **somente** a credencial Firebase do próprio HelpTech em `serviceAccountKey.json` (arquivo privado) e configure Google OAuth/JWT do próprio projeto.
5. Confirme que o backend realmente lê `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `FIREBASE_CREDENTIALS_JSON`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `JWT_SECRET` e `FRONTEND_OAUTH2_REDIRECT_URI` conforme `application.yaml`. Confirme migrações/esquema do banco.
6. Confirme o Dockerfile do frontend: ele deve receber `ARG VITE_API_URL` e definir `ENV VITE_API_URL=$VITE_API_URL` **antes** de `RUN npm run build`. A URL do backend deve ser a URL pública final, não `localhost`.
7. Para Google OAuth funcionar fora de localhost, planeje **HTTPS e domínio** (e callbacks autorizados no Google Cloud). O modelo de dois Load Balancers HTTP pode subir infraestrutura, mas não garante login Google funcional.
8. Revise `rds.tf`: o exemplo desativa `require_secure_transport` e define `skip_final_snapshot=true`, `deletion_protection=false`. **Não use dados reais sem mudar essas políticas**. O state Terraform contém segredos; proteja-o.
9. Antes do deploy, revise disponibilidade de quotas, políticas da conta institucional, região, versão do EKS e preços.

## Execução (somente após validações acima)
```bash
cd ~/HelpTEch_Ops/terraform-eks
aws sts get-caller-identity
terraform init
terraform validate
terraform plan -out=tfplan.out
# Confira custos, recursos e configurações antes de autorizar:
terraform apply tfplan.out
```

## Frontend Vite — exemplo de build
```bash
# Após ter URL pública real do backend e HTTPS configurado
# No diretório do frontend, com Dockerfile ajustado:
docker build --build-arg VITE_API_URL=https://api.seu-dominio.com \
  -t SEU_USUARIO_DOCKERHUB/helptech-frontend:v1 .
# docker push SEU_USUARIO_DOCKERHUB/helptech-frontend:v1
```

**Atenção:** O modelo original implanta frontend antes do backend e exige imagem de frontend já publicada; isso pode demandar um segundo build e redeploy para corrigir a URL pública da API. A automação dessa sequência ainda precisa ser validada.

## Segurança
- **Não inclua** credenciais do FiecLab no HelpTech.
- Não versionar segredos, state ou tfvars.
- `terraform destroy` pode apagar o banco **sem snapshot final** na configuração atual.
- Nenhum `terraform apply`, `destroy`, push ou alteração em AWS foi executado na preparação deste pacote.

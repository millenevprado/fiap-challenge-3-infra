# infra — ToggleMaster

Código Terraform que provisiona toda a infraestrutura AWS do ToggleMaster para o
Tech Challenge Fase 3: networking, cluster EKS (com OIDC/IRSA), bancos de dados
(RDS, ElastiCache, DynamoDB), fila SQS, repositórios ECR, ArgoCD e External
Secrets Operator no cluster.

## Estrutura

```
infra/
├── backend.tf              # backend remoto (S3) + versões dos providers
├── providers.tf            # providers aws, kubernetes, helm, kubectl
├── variables.tf             # variáveis do módulo raiz
├── main.tf                 # conecta todos os módulos + secrets internos
├── outputs.tf               # ARNs/hashes usados nos manifestos do repo gitops
├── terraform.tfvars.example
└── modules/
    ├── networking/       # VPC, subnets públicas/privadas, IGW, NAT, route tables
    ├── eks/              # cluster EKS + node group + OIDC provider (IRSA)
    ├── rds/              # instância RDS Postgres genérica (chamada 3x) + Secrets Manager
    ├── elasticache/      # cluster Redis
    ├── dynamodb/         # tabela ToggleMasterAnalytics
    ├── sqs/              # fila entre evaluation-service e analytics-service
    ├── ecr/              # 5 repositórios de imagem, um por microsserviço
    ├── argocd/           # ArgoCD via Helm + uma Application por microsserviço
    ├── external-secrets/ # External Secrets Operator via Helm + ClusterSecretStore
    └── irsa/             # módulo genérico de IAM Role for Service Accounts
```

As roles de IAM do cluster e dos nós (`modules/eks`) são criadas diretamente
pelo Terraform (`aws_iam_role` + policies gerenciadas da AWS)

## Como rodar

1. Crie manualmente o bucket S3 que vai guardar o `tfstate` (o backend não pode
   se auto-provisionar) e ajuste `backend.tf` com o nome do bucket.
2. Copie `terraform.tfvars.example` para `terraform.tfvars` e ajuste os valores
   (região, tamanhos de instância, `db_user`/`db_pass` etc.).
3. Rode:

   ```bash
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

4. Rode `terraform output` para pegar `service_api_key_hash` (vai na tabela
   `api_keys` do `auth-service`) e os ARNs das roles IRSA de
   `evaluation-service`/`analytics-service` (anotação
   `eks.amazonaws.com/role-arn` nos ServiceAccounts do repo `gitops`).

## ArgoCD

O módulo `argocd` instala o chart Helm `argo-cd` (repo `argoproj/argo-helm`) no
namespace `argocd` do EKS, via os providers `helm`/`kubernetes` configurados em
`providers.tf` (autenticados com `data "aws_eks_cluster_auth"`, sem precisar de
kubeconfig manual). O Service do `argocd-server` fica como `ClusterIP` (sem
LoadBalancer, para não gerar custo extra) — o acesso é por port-forward.

Além do Helm release, o módulo cria (via `kubectl_manifest`, provider
`gavinbunney/kubectl`) uma `Application` do ArgoCD para cada nome em
`var.microservices`, apontando para o subdiretório correspondente do
[`fiap-challenge-3-gitops`](https://github.com/millenevprado/fiap-challenge-3-gitops)
(`var.gitops_repo_url`/`var.gitops_target_revision`), com sync automático
(`prune` + `selfHeal`) — qualquer commit no repo gitops é aplicado sozinho no
cluster, e mudanças manuais feitas fora do Git são revertidas.

Como cluster e ArgoCD nascem no mesmo `apply`, os providers `helm`/`kubernetes`/
`kubectl` dependem de valores que só existem depois do EKS ser criado. Na
primeira vez (cluster ainda não existe), rode em duas etapas:

```bash
terraform apply -target=module.eks
terraform apply
```

Depois de aplicado, configure o `kubectl` e acesse a UI:

```bash
aws eks update-kubeconfig --name togglemaster-eks --region us-east-1

kubectl -n argocd port-forward svc/argocd-server 8080:443
# UI em https://localhost:8080, usuário "admin"

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

## External Secrets Operator + Secrets Manager

O módulo `external-secrets` instala o External Secrets Operator (chart
`external-secrets/external-secrets`) no namespace `external-secrets`, com uma
role IRSA que só tem permissão de `secretsmanager:GetSecretValue`/
`DescribeSecret` nos ARNs listados em `var.secret_arns` — o pod nunca guarda
uma access key estática. O módulo também cria um `ClusterSecretStore`
(`aws-secretsmanager`) compartilhado por todos os namespaces.

Segredos gerados/gerenciados pelo Terraform e disponíveis via Secrets Manager:

- `<identifier>-credentials` (um por RDS: auth/flag/targeting) — usuário, senha,
  host, porta e nome do banco, gerados pelo módulo `rds`.
- `togglemaster-auth-master-key` — chave de assinatura JWT do `auth-service`
  (`random_password`, gerada uma única vez pelo Terraform).
- `togglemaster-service-api-key` — API key interna usada por
  `evaluation-service` para chamar `flag-service`/`targeting-service`; só o
  hash SHA-256 (`service_api_key_hash`, no output) precisa ir para o banco do
  `auth-service` — o valor em texto puro só existe no Secrets Manager.

No repositório `gitops`, cada um desses secrets vira um manifesto
`ExternalSecret` referenciando `secretStoreRef.name: aws-secretsmanager` e
`remoteRef.key: <nome do secret>`.

## IRSA (IAM Roles for Service Accounts)

O módulo `irsa` é genérico: recebe um `policy_json` e cria uma role assumível
via OIDC pelo par namespace/ServiceAccount informado — sem credenciais AWS
estáticas no pod. Hoje é usado por dois microsserviços:

- `irsa_evaluation_service`: permissão de `sqs:SendMessage` na fila de eventos.
- `irsa_analytics_service`: permissão de consumir a fila (`ReceiveMessage`/
  `DeleteMessage`/`GetQueueAttributes`) e escrever na tabela DynamoDB
  (`dynamodb:PutItem`).

Os ARNs das roles saem em `evaluation_service_irsa_role_arn` e
`analytics_service_irsa_role_arn` (via `terraform output`) — usados para
anotar (`eks.amazonaws.com/role-arn`) os ServiceAccounts desses dois
microsserviços no repositório `gitops`.

## CI/CD (`.github/workflows/terraform.yml`)

- **`validate`**: roda em todo `push` para `main`/`master` que altere arquivos `.tf` —
  `terraform fmt -check`, `terraform init` e `terraform validate`.
- **`plan`**: roda em seguida (mesmo evento) e mostra o diff do estado real
  contra o código, sem aplicar nada.
- **`apply`**: só roda via `workflow_dispatch` (botão "Run workflow" na aba
  Actions, escolhendo a opção `apply`) — nenhuma alteração de infraestrutura
  acontece automaticamente por push.

### Secrets necessários no repositório

- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` — IAM user da conta pessoal.
- `TF_VAR_DB_USER` / `TF_VAR_DB_PASS` — equivalentes às variáveis `db_user`/
  `db_pass` do Terraform (nunca commitadas em `terraform.tfvars`).

O job `apply` usa o Environment `production` do GitHub — opcionalmente dá
para configurar um *required reviewer* nele (Settings → Environments) para
exigir uma segunda aprovação antes do apply rodar.

## Custo

Nenhum destes recursos tem free tier completo (EKS control plane e NAT Gateway
nunca são gratuitos). Ver decisão registrada no relatório de entrega sobre uso
de créditos e a rotina de `apply`/`destroy` por sessão de trabalho.

# infra — ToggleMaster

Código Terraform que provisiona toda a infraestrutura AWS do ToggleMaster para o
Tech Challenge Fase 3: networking, cluster EKS, bancos de dados (RDS, ElastiCache,
DynamoDB), fila SQS e repositórios ECR.

## Estrutura

```
infra/
├── backend.tf              # backend remoto (S3) + versões dos providers
├── providers.tf            # provider AWS
├── variables.tf            # variáveis do módulo raiz
├── main.tf                 # conecta todos os módulos
├── outputs.tf              # endpoints/ARNs usados depois pelos Secrets do K8s
├── terraform.tfvars.example
└── modules/
    ├── networking/   # VPC, subnets públicas/privadas, IGW, NAT, route tables
    ├── eks/          # cluster EKS + node group (LabRole ou IAM próprio)
    ├── rds/          # módulo genérico de instância RDS Postgres (chamado 3x)
    ├── elasticache/  # cluster Redis
    ├── dynamodb/     # tabela ToggleMasterAnalytics
    ├── sqs/          # fila entre evaluation-service e analytics-service
    ├── ecr/          # 5 repositórios de imagem, um por microsserviço
    └── argocd/       # ArgoCD via Helm (provider helm), instalado no EKS
```

## AWS Academy x Conta pessoal

A variável `use_lab_role` controla o módulo `eks`:

- `use_lab_role = true` (padrão): não cria nenhuma role/policy de IAM. O módulo
  importa a `LabRole` existente via `data "aws_iam_role"` e a associa ao cluster
  e ao node group.
- `use_lab_role = false`: o módulo cria as roles de IAM do zero (cluster role +
  node role com as policies gerenciadas da AWS).

## Como rodar

1. Crie manualmente o bucket S3 que vai guardar o `tfstate` (o backend não pode
   se auto-provisionar) e ajuste `backend.tf` com o nome do bucket.
2. Copie `terraform.tfvars.example` para `terraform.tfvars` e ajuste os valores
   (região, `use_lab_role`, tamanhos de instância etc.).
3. Rode:

   ```bash
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

4. Anote os outputs (`terraform output`) — os endpoints de RDS/Redis, o nome da
   tabela DynamoDB, a URL/ARN da fila SQS e as URLs dos repositórios ECR viram
   Secrets/ConfigMaps nos manifestos do repositório `gitops`.
5. Quando não estiver usando (fim do dia de trabalho, entre sessões de teste),
   rode `terraform destroy` — EKS, NAT Gateway e RDS são cobrados por hora
   mesmo parados/ociosos.

## ArgoCD

O módulo `argocd` instala o chart Helm `argo-cd` (repo `argoproj/argo-helm`) no
namespace `argocd` do EKS, via os providers `helm`/`kubernetes` configurados em
`providers.tf` (autenticados com `data "aws_eks_cluster_auth"`, sem precisar de
kubeconfig manual). O Service do `argocd-server` fica como `ClusterIP` (sem
LoadBalancer, para não gerar custo extra) — o acesso é por port-forward.

Como cluster e ArgoCD nascem no mesmo `apply`, os providers `helm`/`kubernetes`
dependem de valores que só existem depois do EKS ser criado. Na primeira vez
(cluster ainda não existe), rode em duas etapas:

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

A partir daí, a próxima etapa é criar as `Application` do ArgoCD apontando
para o repositório [`fiap-challenge-3-gitops`](https://github.com/millenevprado/fiap-challenge-3-gitops)
(uma por microsserviço, cada uma sincronizando seu próprio subdiretório).

## CI/CD (`.github/workflows/terraform.yml`)

- **`validate`**: roda em todo `push` para `main` que altere arquivos `.tf` —
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

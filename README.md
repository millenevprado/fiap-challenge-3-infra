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
    └── ecr/          # 5 repositórios de imagem, um por microsserviço
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

## Custo

Nenhum destes recursos tem free tier completo (EKS control plane e NAT Gateway
nunca são gratuitos). Ver decisão registrada no relatório de entrega sobre uso
de créditos e a rotina de `apply`/`destroy` por sessão de trabalho.

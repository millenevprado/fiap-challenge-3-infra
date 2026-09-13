terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
  }

  backend "s3" {
    bucket       = "togglemaster-fiap-tfstate"
    key          = "infra/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

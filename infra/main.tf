terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_codeartifact_domain" "main" {
  domain = "devcontainer-poc"
}

resource "aws_codeartifact_repository" "private" {
  domain     = aws_codeartifact_domain.main.domain
  repository = "private-python"
}

data "aws_codeartifact_repository_endpoint" "pip" {
  domain     = aws_codeartifact_domain.main.domain
  repository = aws_codeartifact_repository.private.repository
  format     = "pypi"
}


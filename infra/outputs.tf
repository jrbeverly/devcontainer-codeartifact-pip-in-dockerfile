output "domain" {
  value = aws_codeartifact_domain.main.domain
}

output "domain_owner" {
  value = aws_codeartifact_domain.main.owner
}

output "repository" {
  value = aws_codeartifact_repository.private.repository
}

output "region" {
  value = var.region
}

output "pip_endpoint" {
  value = data.aws_codeartifact_repository_endpoint.pip.repository_endpoint
}

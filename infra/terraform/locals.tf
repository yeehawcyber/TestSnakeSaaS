locals {
  name_prefix = "${var.project_name}-${var.environment}"
  public_url  = "https://${var.domain_name}"

  common_tags = merge(
    {
      Application = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = var.github_repository
    },
    var.additional_tags,
  )
}

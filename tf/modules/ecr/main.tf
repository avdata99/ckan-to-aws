# ECR Repository for CKAN
resource "aws_ecr_repository" "ckan" {
  name                 = "${var.project_id}-${var.environment}-${var.ckan_repo_name}"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_id}-${var.environment}-${var.ckan_repo_name}"
  }
}

# ECR Repository for Solr
resource "aws_ecr_repository" "solr" {
  name                 = "${var.project_id}-${var.environment}-${var.solr_repo_name}"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_id}-${var.environment}-${var.solr_repo_name}"
  }
}

# ECR Repository for Redis/Valkey
resource "aws_ecr_repository" "redis" {
  name                 = "${var.project_id}-${var.environment}-${var.redis_repo_name}"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_id}-${var.environment}-${var.redis_repo_name}"
  }
}

# Lifecycle policy to keep only recent images
resource "aws_ecr_lifecycle_policy" "ckan" {
  repository = aws_ecr_repository.ckan.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last ${var.image_retention_count} images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = var.image_retention_count
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "solr" {
  repository = aws_ecr_repository.solr.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last ${var.image_retention_count} images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = var.image_retention_count
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "redis" {
  repository = aws_ecr_repository.redis.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last ${var.image_retention_count} images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = var.image_retention_count
      }
      action = {
        type = "expire"
      }
    }]
  })
}

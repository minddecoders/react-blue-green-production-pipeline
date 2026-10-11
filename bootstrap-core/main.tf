terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

# ============================================================================
# 🛰️ 1. GLOBAL OIDC IDENTITY PROVIDER HOOK
# ============================================================================
resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # Cleaned up to include standard trusted root/intermediate thumbprints for GitHub Actions
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

# ============================================================================
# 🛡️ 2. PERMANENT KEYLESS EXECUTION ROLE ASSUMED BY GITHUB ACTIONS
# ============================================================================
resource "aws_iam_role" "github_oidc_role" {
  name        = "sidra-github-actions-oidc-execution-role"
  description = "Permanent role assumed by automated GitHub Actions runners using temporary keyless session tokens"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github_actions.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # ✅ IMMUTABLE & MULTI-EVENT FIX: 
            # This safely accepts branch pushes, manual triggers, AND pull requests 
            # while gracefully capturing internal tracking IDs (@...) introduced by GitHub.
            "token.actions.githubusercontent.com:sub" = [
            "repo:minddecoders*/react-blue-green-production-pipeline*:*"]
          }
        }
      }
    ]
  })
}

# ============================================================================
# 🛡️ 3. ATTACH ADMINISTRATOR PERMISSION POLICY WIRE
# ============================================================================
resource "aws_iam_role_policy_attachment" "oidc_admin_attach" {
  role       = aws_iam_role.github_oidc_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ============================================================================
# 📡 PHASE 8 TELEMETRY OUTPUT
# ============================================================================
output "github_actions_oidc_role_arn" {
  value       = aws_iam_role.github_oidc_role.arn
  description = "The target IAM role ARN used by GitHub Actions for temporary AWS credentials"
}

# ============================================================================
# PHASE 10: ENTERPRISE DISASTER RECOVERY • IMMUTABLE STATE STORAGE VAULT
# ============================================================================

# 1. References or declares your central S3 bucket mapping identifier
resource "aws_s3_bucket" "state_vault" {
  bucket        = "sidra-prod-state-vault-2026"
  force_destroy = false # 🔒 MAXIMUM RISK PROTECTION: Prevents accidental total bucket destruction sweeps!

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform-IaC"
    Security    = "Versioned-State-Vault"
  }
}

# 2. Hardens the storage parameters by enabling explicit object versioning chains
resource "aws_s3_bucket_versioning" "state_vault_versioning" {
  bucket = aws_s3_bucket.state_vault.id

  versioning_configuration {
    status = "Enabled" # 🔄 FORCES S3 TO CONSTRUCT HISTORICAL VERSION SNAPSHOTS PERMANENTLY!
  }
}
# ============================================================================
# PHASE 11: ENTERPRISE SECRETS PROTECTION • CRYPTOGRAPHIC FABRIC (TRACK 9)
# ============================================================================

# 🔐 1. Manufacture Your Dedicated Customer-Managed AWS KMS Encryption Key
resource "aws_kms_key" "sidra_vault_key" {
  description             = "Master customer-managed key used to encrypt infrastructure secrets for the React Monorepo"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform-IaC"
    Protection  = "KMS-Cryptographic-Shield"
  }
}

# 🏷️ 2. Build a Human-Readable Alias Link for Your KMS Key
resource "aws_kms_alias" "sidra_vault_key_alias" {
  name          = "alias/sidra-monorepo-vault-key"
  target_key_id = aws_kms_key.sidra_vault_key.key_id
}

# 🗄️ 3. PROVISION THE HARDWARE-BACKED AWS SECRETS MANAGER VAULT CONTAINER SLOT
# 🔄 SYNCED: Removed the extra underscore character from 'aws_secretsmanager_secret'!
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "sidra-react-monorepo-db-secrets"
  description             = "Hardware-encrypted production database credential store vault"
  kms_key_id              = aws_kms_key.sidra_vault_key.arn
  recovery_window_in_days = 0

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform-IaC"
  }
}

# ============================================================================
# PHASE 11 TELEMETRY OUTPUTS: Surface Your Security Identifiers
# ============================================================================
output "kms_key_arn" {
  value       = aws_kms_key.sidra_vault_key.arn
  description = "The absolute cryptographic Amazon Resource Name wire address of your KMS encryption key"
}

# 🔄 SYNCED: Updated reference to match the correct resource identifier pattern!
output "secrets_manager_arn" {
  value       = aws_secretsmanager_secret.db_credentials.arn
  description = "The target Amazon Resource Name tracking address of your secure secrets vault slot"
}


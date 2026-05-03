# AWS Account Setup

Use this if the AWS account is new and you want a clean baseline before deploying the exit node.

## Before deployment

1. Create the AWS account and finish identity verification.
2. Choose the free/basic support plan unless you intentionally want a paid support tier.
3. Create an administrative IAM user or IAM Identity Center access path instead of using the root user for daily work.
4. Turn on MFA for the root user and for your admin user.
5. Store billing and security contact details in the account settings.

## Billing guardrails

1. In the AWS Billing console, enable billing alerts for the account.
2. Set a budget or alarm before the first deploy.
3. Decide which email address should receive spend alerts.
4. Review the free-tier and credit terms directly in the AWS console before relying on them. Those terms change over time.

This Terraform stack can create a billing alarm automatically when `billing_alert_email` is set, but the account-level billing alert preference still needs to be enabled in AWS first.

## Credentials for Terraform

Use one of these:

- `aws configure`
- Environment variables such as `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_REGION`
- SSO or federated credentials if that is how the account is managed

Verify access before deployment:

```bash
aws sts get-caller-identity
```

## Recommended first deploy path

1. Copy `terraform.tfvars.example` to `terraform.tfvars`.
2. Set the Tailscale auth key and optional billing alert email.
3. Run `terraform init`, `terraform plan`, and `terraform apply`.
4. Approve the exit node in the Tailscale admin console after the instance boots.

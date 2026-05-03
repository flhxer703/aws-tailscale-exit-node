<!-- markdownlint-disable -->
><img src="https://github.com/flhxer703/aws-tailscale-exit-node/blob/main/.github/banner.png?raw=true" alt="Project Banner"/></a><br/>
<!-- markdownlint-restore -->

# Tailscale Exit Node on AWS

Deploy a single EC2 instance as a Tailscale exit node with a minimal VPC, optional Session Manager access, optional CloudWatch logs, and an optional billing alarm.

For first-time AWS account setup, see [AWS_ACCOUNT_SETUP.md](AWS_ACCOUNT_SETUP.md).

## What this creates

- One VPC with one public subnet and an internet gateway
- One Amazon Linux 2023 EC2 instance with Tailscale installed at boot
- One security group with no inbound rules
- Optional SSM instance profile for shell access without SSH
- Optional CloudWatch log group and agent configuration
- Optional billing alarm in `us-east-1` when `billing_alert_email` is set

## Prerequisites

- Terraform `>= 1.5`
- AWS credentials configured locally
- A Tailscale auth key
- Billing alerts enabled in the AWS account if you want the Terraform-managed alarm

## Quick start

1. Copy the example variable file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

1. Edit `terraform.tfvars` and set at least:

```hcl
tailscale_auth_key  = "tskey-auth-XXXXXXXXXXXX-XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
billing_alert_email = "you@example.com" # optional
```

1. Deploy:

```bash
terraform init
terraform plan
terraform apply
```

1. Approve the exit node in the Tailscale admin console.

## Access

If `enable_ssm = true`:

```bash
aws ssm start-session --target $(terraform output -raw instance_id)
```

There is no SSH ingress rule in this stack.

## Important behavior

- `source_dest_check` is disabled on the instance because exit-node forwarding requires it.
- If `availability_zone` is left unset, Terraform picks the first available AZ in the selected region.
- If `billing_alert_email` is empty, billing alarm resources are skipped.
- Billing alarms are created in `us-east-1` because AWS billing metrics live there.
- The instance gets an auto-assigned public IP. Stopping and starting it will usually change that IP.

## Troubleshooting

- Tailscale node never appears: verify the auth key is valid and not expired.
- SSM session fails: wait a few minutes after boot and confirm the instance profile was attached.
- Billing alarm does not show charges immediately: AWS billing metrics are delayed and update infrequently.
- CloudWatch logs missing: check `amazon-cloudwatch-agent` status from SSM.

## Terraform Reference

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |
| <a name="provider_aws.us_east_1"></a> [aws.us\_east\_1](#provider\_aws.us\_east\_1) | 5.100.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.tailscale](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.billing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_iam_instance_profile.ssm_core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.ssm_core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.cloudwatch_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ssm_core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.tailscale_exit_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_internet_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.tailscale](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_sns_topic.billing_alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_subscription.billing_email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_ami.amazon_linux_2023](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | Availability zone for the subnet. Leave null to use the first available zone in the selected region. | `string` | `null` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region to deploy to | `string` | `"us-east-1"` | no |
| <a name="input_billing_alert_email"></a> [billing\_alert\_email](#input\_billing\_alert\_email) | Email address for billing alerts. Leave empty to skip creating billing alarm resources. | `string` | `""` | no |
| <a name="input_enable_cloudwatch_logs"></a> [enable\_cloudwatch\_logs](#input\_enable\_cloudwatch\_logs) | Install and configure CloudWatch Logs agent | `bool` | `true` | no |
| <a name="input_enable_ssm"></a> [enable\_ssm](#input\_enable\_ssm) | Attach SSM IAM instance profile for Session Manager access | `bool` | `true` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type | `string` | `"t3.micro"` | no |
| <a name="input_subnet_cidr"></a> [subnet\_cidr](#input\_subnet\_cidr) | CIDR block for the public subnet | `string` | `"10.0.1.0/24"` | no |
| <a name="input_tailscale_auth_key"></a> [tailscale\_auth\_key](#input\_tailscale\_auth\_key) | Tailscale auth key for node registration | `string` | n/a | yes |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the VPC | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | ID of the EC2 instance |
| <a name="output_instance_public_ip"></a> [instance\_public\_ip](#output\_instance\_public\_ip) | Public IP address of the Tailscale exit node |
| <a name="output_ssm_command"></a> [ssm\_command](#output\_ssm\_command) | AWS CLI command to connect via Session Manager |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the created VPC |
<!-- END_TF_DOCS -->

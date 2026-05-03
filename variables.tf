variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "tailscale_auth_key" {
  description = "Tailscale auth key for node registration"
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the subnet. Leave null to use the first available zone in the selected region."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_ssm" {
  description = "Attach SSM IAM instance profile for Session Manager access"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_logs" {
  description = "Install and configure CloudWatch Logs agent"
  type        = bool
  default     = true
}

variable "billing_alert_email" {
  description = "Email address for billing alerts. Leave empty to skip creating billing alarm resources."
  type        = string
  default     = ""

  validation {
    condition     = var.billing_alert_email == "" || can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", var.billing_alert_email))
    error_message = "billing_alert_email must be empty or a valid email address."
  }
}

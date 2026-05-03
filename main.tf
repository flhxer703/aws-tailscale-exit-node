provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  selected_availability_zone = coalesce(var.availability_zone, data.aws_availability_zones.available.names[0])
  billing_alarm_enabled      = var.billing_alert_email != ""
  instance_role_enabled      = var.enable_ssm || var.enable_cloudwatch_logs
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "tailscale-exit-node-vpc"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  availability_zone       = local.selected_availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "tailscale-public-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "tailscale-igw"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "tailscale-public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "tailscale" {
  name        = "tailscale-exit-node-sg"
  description = "Security group for Tailscale exit node"
  vpc_id      = aws_vpc.main.id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tailscale-exit-node-sg"
  }
}

# SSM IAM Role (Always Free)
resource "aws_iam_role" "ssm_core" {
  count = local.instance_role_enabled ? 1 : 0

  name = "tailscale-ssm-core-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "tailscale-ssm-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  count = var.enable_ssm ? 1 : 0

  role       = aws_iam_role.ssm_core[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  role       = aws_iam_role.ssm_core[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ssm_core" {
  count = local.instance_role_enabled ? 1 : 0

  name = "tailscale-ssm-core-profile"
  role = aws_iam_role.ssm_core[0].name
}

# CloudWatch Log Group (Always Free: 5 GB ingestion/month)
resource "aws_cloudwatch_log_group" "tailscale" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name              = "/tailscale/exit-node"
  retention_in_days = 7 # Free tier friendly, adjust as needed

  tags = {
    Name = "tailscale-exit-node-logs"
  }
}

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instance
resource "aws_instance" "tailscale_exit_node" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.tailscale.id]
  iam_instance_profile        = local.instance_role_enabled ? aws_iam_instance_profile.ssm_core[0].name : null
  source_dest_check           = false
  user_data_replace_on_change = true

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    # Update system
    dnf update -y

    # Install and configure Tailscale
    dnf config-manager --add-repo https://pkgs.tailscale.com/stable/amazon-linux/2023/tailscale.repo
    dnf install -y tailscale

    # Enable IP forwarding for exit node functionality
    echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/99-tailscale.conf
    echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.d/99-tailscale.conf
    sysctl -p /etc/sysctl.d/99-tailscale.conf

    # Start and enable tailscaled
    systemctl enable --now tailscaled

    # Bring up Tailscale with auth key as exit node
    tailscale up --authkey='${var.tailscale_auth_key}' --advertise-exit-node --accept-dns=true

    %{if var.enable_cloudwatch_logs}
    # Install and configure CloudWatch Agent
    dnf install -y amazon-cloudwatch-agent

    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWCONFIG'
    {
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/messages",
                "log_group_name": "${aws_cloudwatch_log_group.tailscale[0].name}",
                "log_stream_name": "{instance_id}/messages",
                "timezone": "UTC"
              },
              {
                "file_path": "/var/log/tailscale-setup.log",
                "log_group_name": "${aws_cloudwatch_log_group.tailscale[0].name}",
                "log_stream_name": "{instance_id}/tailscale-setup",
                "timezone": "UTC"
              }
            ]
          }
        }
      },
      "metrics": {
        "namespace": "TailscaleExitNode",
        "metrics_collected": {
          "disk": {
            "measurement": ["used_percent"],
            "resources": ["*"]
          },
          "mem": {
            "measurement": ["mem_used_percent"]
          },
          "cpu": {
            "measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"],
            "metrics_collection_interval": 60,
            "totalcpu": true
          }
        }
      }
    }
    CWCONFIG

    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
    %{endif}

    # Signal success
    echo "Tailscale exit node configured successfully at $(date)" > /var/log/tailscale-setup.log
  EOF

  tags = {
    Name = "tailscale-exit-node"
  }
}

# CloudWatch Billing Alarm (Always Free: 10 alarms)
resource "aws_cloudwatch_metric_alarm" "billing" {
  count    = local.billing_alarm_enabled ? 1 : 0
  provider = aws.us_east_1

  alarm_name          = "tailscale-monthly-budget"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400" # Daily check
  statistic           = "Maximum"
  threshold           = "10" # $10 USD alert threshold
  alarm_description   = "Alert when estimated monthly charges exceed $10"
  alarm_actions       = [aws_sns_topic.billing_alerts[0].arn]

  dimensions = {
    Currency = "USD"
  }
}

# SNS Topic for billing alerts
resource "aws_sns_topic" "billing_alerts" {
  count    = local.billing_alarm_enabled ? 1 : 0
  provider = aws.us_east_1

  name = "tailscale-billing-alerts"
}

# Email subscription for billing alerts
resource "aws_sns_topic_subscription" "billing_email" {
  count     = local.billing_alarm_enabled ? 1 : 0
  provider  = aws.us_east_1
  topic_arn = aws_sns_topic.billing_alerts[0].arn
  protocol  = "email"
  endpoint  = var.billing_alert_email
}

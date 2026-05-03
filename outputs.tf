output "instance_public_ip" {
  description = "Public IP address of the Tailscale exit node"
  value       = aws_instance.tailscale_exit_node.public_ip
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.tailscale_exit_node.id
}

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "ssm_command" {
  description = "AWS CLI command to connect via Session Manager"
  value       = var.enable_ssm ? "aws ssm start-session --target ${aws_instance.tailscale_exit_node.id}" : "SSM not enabled"
}

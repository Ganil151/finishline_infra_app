#========================================================================
#                   *** Virtual Private Cloud Outputs ***
#========================================================================
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.finishline_vpc.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.finishline_vpc.cidr_block
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = aws_vpc.finishline_vpc.arn
}

#========================================================================
#                   *** Internet Gateway Outputs ***
#========================================================================
output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.finishline_igw.id
}

#========================================================================
#                   *** EIP Outputs ***
#========================================================================
output "nat_eip_ids" {
  description = "The IDs of the Elastic IPs"
  value       = aws_eip.finishline_eip[*].id
}

output "nat_eip_public_ips" {
  description = "The public IPs of the Elastic IPs"
  value       = aws_eip.finishline_eip[*].public_ip
}

#========================================================================
#                   *** Subnet Outputs ***
#========================================================================
output "public_subnet_ids" {
  description = "List of IDs of the public subnets"
  value       = aws_subnet.finishline_public_subnet[*].id
}

output "public_subnet_arns" {
  description = "List of ARNs of the public subnets"
  value       = aws_subnet.finishline_public_subnet[*].arn
}

output "public_subnet_cidrs" {
  description = "List of CIDR blocks of the public subnets"
  value       = aws_subnet.finishline_public_subnet[*].cidr_block
}

output "public_subnet_availability_zones" {
  description = "List of availability zones of the public subnets"
  value       = aws_subnet.finishline_public_subnet[*].availability_zone
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets"
  value       = aws_subnet.finishline_private_subnet[*].id
}

output "private_subnet_arns" {
  description = "List of ARNs of the private subnets"
  value       = aws_subnet.finishline_private_subnet[*].arn
}

output "private_subnet_cidrs" {
  description = "List of CIDR blocks of the private subnets"
  value       = aws_subnet.finishline_private_subnet[*].cidr_block
}

output "private_subnet_availability_zones" {
  description = "List of availability zones of the private subnets"
  value       = aws_subnet.finishline_private_subnet[*].availability_zone
}

#========================================================================
#                   *** NAT Gateway Outputs ***
#========================================================================
output "nat_gateway_ids" {
  description = "List of IDs of the NAT gateways"
  value       = aws_nat_gateway.finishline_nat_gateway[*].id
}

output "nat_gateway_public_ips" {
  description = "List of public IPs of the NAT gateways"
  value       = aws_nat_gateway.finishline_nat_gateway[*].public_ip
}

output "nat_gateway_private_ips" {
  description = "List of private IPs of the NAT gateways"
  value       = aws_nat_gateway.finishline_nat_gateway[*].private_ip
}

#========================================================================
#                   *** Route Table Outputs ***
#========================================================================
output "public_route_table_id" {
  description = "The ID of the public route table"
  value       = aws_route_table.finishline_public_route_table.id
}

output "private_route_table_id" {
  description = "The ID of the private route table"
  value       = aws_route_table.finishline_private_route_table.id
}

#========================================================================
#                   *** Network ACL Outputs ***
#========================================================================
output "network_acl_id" {
  description = "The ID of the network ACL"
  value       = aws_network_acl.finishline_network_acl.id
}

output "network_acl_arn" {
  description = "The ARN of the network ACL"
  value       = aws_network_acl.finishline_network_acl.arn
}

#========================================================================
#                   *** VPC Endpoint Outputs ***
#========================================================================
output "vpc_endpoints_sg_id" {
  description = "The ID of the VPC endpoints security group"
  value       = try(aws_security_group.finishline_vpc_endpoints_sg[0].id, null)
}

output "vpc_endpoints_sg_arn" {
  description = "The ARN of the VPC endpoints security group"
  value       = try(aws_security_group.finishline_vpc_endpoints_sg[0].arn, null)
}

output "eks_endpoint_id" {
  description = "The ID of the EKS VPC endpoint"
  value       = try(aws_vpc_endpoint.finishline_eks_endpoint[0].id, null)
}

output "eks_endpoint_dns_entry" {
  description = "The DNS entry of the EKS VPC endpoint"
  value       = try(aws_vpc_endpoint.finishline_eks_endpoint[0].dns_entry, null)
}

output "sts_endpoint_id" {
  description = "The ID of the STS VPC endpoint"
  value       = try(aws_vpc_endpoint.finishline_sts_endpoint[0].id, null)
}

output "sts_endpoint_dns_entry" {
  description = "The DNS entry of the STS VPC endpoint"
  value       = try(aws_vpc_endpoint.finishline_sts_endpoint[0].dns_entry, null)
}

output "ec2_endpoint_id" {
  description = "The ID of the EC2 VPC endpoint"
  value       = try(aws_vpc_endpoint.finishline_ec2_endpoint[0].id, null)
}

output "ec2_endpoint_dns_entry" {
  description = "The DNS entry of the EC2 VPC endpoint"
  value       = try(aws_vpc_endpoint.finishline_ec2_endpoint[0].dns_entry, null)
}

output "s3_endpoint_id" {
  description = "The ID of the S3 VPC endpoint"
  value       = try(aws_vpc_endpoint.finishline_s3_endpoint[0].id, null)
}

output "s3_endpoint_dns_entry" {
  description = "The DNS entry of the S3 VPC endpoint"
  value       = try(aws_vpc_endpoint.finishline_s3_endpoint[0].dns_entry, null)
}

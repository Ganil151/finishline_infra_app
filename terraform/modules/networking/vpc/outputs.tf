# ===========================================================
#          ***   VPC Outputs Config   ***
# ===========================================================
output "vpc_id" {
  value = aws_vpc.finishline_vpc.id
}
output "public_subnets_ids" {
  value = aws_subnet.finishline_public_subnet[*].id
}
output "private_subnets_ids" {
  value = aws_subnet.finishline_private_subnet[*].id
}
output "nat_gateway_ids" {
  value = aws_nat_gateway.finishline_nat_gw[*].id
}
output "internet_gateway_ids" {
  value = aws_internet_gateway.finishline_igw.id
}
output "route_table_ids" {
  value = [aws_route_table.finishline_public_rt.id, aws_route_table.finishline_private_rt.id]
}
# ===========================================================
#          ***   VPC Endpoint Outputs   ***
# ===========================================================
output "eks_endpoint_id" {
  description = "ID of the EKS API VPC endpoint"
  value       = try(aws_vpc_endpoint.eks_endpoint[0].id, "")
}

output "eks_endpoint_dns_entry" {
  description = "DNS entry for the EKS API VPC endpoint"
  value       = try(aws_vpc_endpoint.eks_endpoint[0].dns_entry, [])
}

output "sts_endpoint_id" {
  description = "ID of the STS VPC endpoint"
  value       = try(aws_vpc_endpoint.sts[0].id, "")
}

output "ec2_endpoint_id" {
  description = "ID of the EC2 VPC endpoint"
  value       = try(aws_vpc_endpoint.ec2[0].id, "")
}

output "s3_endpoint_id" {
  description = "ID of the S3 VPC endpoint"
  value       = try(aws_vpc_endpoint.s3[0].id, "")
}

output "vpc_endpoints_security_group_id" {
  description = "ID of the security group for VPC interface endpoints"
  value       = try(aws_security_group.vpc_endpoints[0].id, "")
}

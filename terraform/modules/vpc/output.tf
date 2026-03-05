output "main_vpc_id" {
  value = aws_vpc.finishline_vpc.id
}

output "main_public_subnet_ids" {
  value = aws_subnet.finishline_public_subnet[*].id
}

output "main_private_subnet_ids" {
  value = aws_subnet.finishline_private_subnet[*].id
}

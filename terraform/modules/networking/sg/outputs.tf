# ===========================================================
#            ***   Security Group Outputs   ***
# ===========================================================
output "security_group_id" {
  value = aws_security_group.finishline_sg.id
}
output "security_group_name" {
  value = aws_security_group.finishline_sg.name
}
output "security_group_description" {
  value = aws_security_group.finishline_sg.description
}
output "security_group_arn" {
  value = aws_security_group.finishline_sg.arn
}

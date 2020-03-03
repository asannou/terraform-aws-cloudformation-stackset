output "arn" {
  value = aws_iam_role.role.arn
}

output "execution_role_name" {
  value = var.execution_role_name
}


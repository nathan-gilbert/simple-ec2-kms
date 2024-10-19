output "flask_app_public_ip" {
  value = aws_instance.flask_instance.public_ip
}

output "db_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "flask_app_public_ip" {
  value = aws_instance.flask_instance.public_ip
}

output "db_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "db_password" {
  value = random_password.db_password.result
  sensitive = true
}

output "cipher_text" {
  value = aws_kms_ciphertext.db_password_encrypted.ciphertext_blob
  sensitive = true
}

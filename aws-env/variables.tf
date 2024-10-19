variable "aws_region" {
  default = "us-west-1"
}

variable "aws_availability_zone" {
  default = "us-west-1a"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
}

variable "key_pair_name" {
  description = "EC2 key pair name"
}

variable "db_name" {
  default = "mydatabase"
}

variable "db_user" {
  default = "admin"
}

variable "db_password" {
  description = "Database password"
  sensitive   = true
}

variable "aws_access_key" {}

variable "aws_secret_key" {}

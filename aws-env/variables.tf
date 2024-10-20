variable "aws_region" {
  default = "us-west-1"
}

variable "aws_availability_zone" {
  default = "us-west-1b"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  default = "ami-0da424eb883458071"
}

variable "instance_name" {
  description = "EC2 instance name"
  default = "FlaskAppInstance"
}

variable "db_name" {
  default = "mydatabase"
}

variable "db_user" {
  default = "app_user"
}

variable "kms_user" {
  description = "The IAM user who needs access to the KMS key"
  type        = string
  default     = "nathan"
}

variable "aws_access_key" {}

variable "aws_secret_key" {}

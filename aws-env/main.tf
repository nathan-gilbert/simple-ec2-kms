resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.aws_availability_zone
}

resource "aws_security_group" "allow_all" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "flask_instance" {
  ami                         = var.ami_id
  instance_type              = "t2.micro"
  subnet_id                  = aws_subnet.public.id
  security_groups            = [aws_security_group.allow_all.name]
  associate_public_ip_address = true
  key_name                   = var.key_pair_name
  user_data                  = file("user_data.sh")

  tags = {
    Name = "FlaskAppInstance"
  }
}

resource "aws_db_instance" "postgres" {
  allocated_storage       = 20
  engine                  = "postgres"
  engine_version          = "12.7"
  instance_class          = "db.t2.micro"
  identifier              = var.db_name
  username                = var.db_user
  password                = var.db_password
  parameter_group_name    = "default.postgres12"
  publicly_accessible     = true
  skip_final_snapshot     = true
  vpc_security_group_ids  = [aws_security_group.allow_all.id]
  db_subnet_group_name    = aws_db_subnet_group.main.name
}

resource "aws_db_subnet_group" "main" {
  name       = "main"
  subnet_ids = [aws_subnet.public.id]
}

resource "aws_kms_key" "db_credentials" {
  description = "KMS key for encrypting DB credentials"
}

resource "aws_kms_ciphertext" "db_password_encrypted" {
  key_id = aws_kms_key.db_credentials.id
  plaintext = var.db_password
}

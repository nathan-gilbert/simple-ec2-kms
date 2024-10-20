# SSH Key Configuration
resource "tls_private_key" "ec2_instance_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Generate a Private Key and encode it as PEM.
resource "aws_key_pair" "ec2_instance_key_pair" {
  key_name   = "${replace(lower(var.instance_name), " ", "-")}_key"
  public_key = tls_private_key.ec2_instance_key.public_key_openssh

  provisioner "local-exec" {
    command     = "echo '${tls_private_key.ec2_instance_key.private_key_pem}' > ./${var.instance_name}_key.pem"
    interpreter = ["pwsh", "-Command"]
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-1b"
}

resource "aws_subnet" "rds_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-west-1c"
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

resource "random_password" "db_password" {
  length  = 16
  special = true
}

resource "aws_kms_key" "db_credentials" {
  description         = "KMS key for encrypting DB credentials"
  key_usage           = "ENCRYPT_DECRYPT"
  is_enabled          = true
  enable_key_rotation = true

  policy = <<EOF
  {
    "Version": "2012-10-17",
    "Id": "key-policy-1",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        "Action": "kms:*",
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.ec2_role.name}"
        },
        "Action": [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.kms_user}"
        },
        "Action": [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:RevokeGrant"
        ],
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2-db-creds-role"

  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  EOF
}

resource "aws_iam_policy" "ec2_policy" {
  name        = "ec2-policy"
  description = "Policy for EC2 instance to access KMS and S3"
  policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "kms:Encrypt",
          "kms:Decrypt",
          "s3:ListBucket",
          "s3:GetObject"
        ],
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy_attachment" "ec2_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_kms_alias" "db_creds_alias" {
  name          = "alias/db-key"
  target_key_id = aws_kms_key.db_credentials.id
}

resource "aws_kms_ciphertext" "db_password_encrypted" {
  key_id    = aws_kms_key.db_credentials.id
  plaintext = random_password.db_password.result
}

resource "aws_db_subnet_group" "main" {
  name       = "db_subnet_group"
  subnet_ids = [aws_subnet.public.id, aws_subnet.rds_subnet.id]
}

resource "aws_db_instance" "postgres" {
  allocated_storage       = 20
  engine                  = "postgres"
  engine_version          = "16.4"
  instance_class          = "db.t4g.micro"
  identifier              = var.db_name
  username                = var.db_user
  password                = random_password.db_password.result
  parameter_group_name    = "default.postgres16"
  publicly_accessible     = true
  skip_final_snapshot     = true
  vpc_security_group_ids  = [aws_security_group.allow_all.id]
  db_subnet_group_name    = aws_db_subnet_group.main.name

  depends_on = [aws_security_group.allow_all]
}

resource "aws_instance" "flask_instance" {
  ami                         = var.ami_id
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.allow_all.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ec2_instance_key_pair.id
  user_data                   = templatefile("${path.module}/user_data.tpl", {
    encrypted_password = aws_kms_ciphertext.db_password_encrypted.ciphertext_blob
    db_name            = var.db_name
    db_user            = var.db_user
    db_endpoint        = split(":", aws_db_instance.postgres.endpoint)[0]
  })

  tags = {
    Name = "FlaskAppInstance"
  }
}

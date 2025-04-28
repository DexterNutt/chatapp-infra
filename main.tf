terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
  default_tags {
    tags = {
      Project = "Internship"
    }
  }
}

provider "random" {}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "test_bucket" {
  bucket = "test-bucket-${random_id.suffix.hex}"
  tags = {
    Project = "Internship"
  }
}

resource "aws_iam_role" "ec2_s3_role" {
  name = "test-ec2-s3-role"
  tags = {
    Project = "Internship"
  }
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "s3_read_policy" {
  name        = "s3-read-write-policy"
  description = "Allows read access to the test bucket"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      Resource = [
        aws_s3_bucket.test_bucket.arn,
        "${aws_s3_bucket.test_bucket.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = aws_iam_policy.s3_read_policy.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-s3-profile"
  role = aws_iam_role.ec2_s3_role.name
  tags = {
    Project = "Internship"
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow-ssh"
  description = "Allow SSH inbound traffic"
  tags = {
    Project = "Internship"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_instance" "test_instance" {
  ami                  = "ami-08f78cb3cc8a4578e"  
  instance_type        = "t3.nano"
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  tags = {
    Name    = "S3-Test-Instance",
    Project = "Internship"
  }
}

output "s3_bucket_name" {
  value = aws_s3_bucket.test_bucket.bucket
}

output "ec2_public_ip" {
  value = aws_instance.test_instance.public_ip
}
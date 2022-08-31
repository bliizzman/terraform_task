provider "aws" {
  access_key = "*******"
  secret_key = "*******"
  region = "eu-central-1"
}
module "vpc" {
  source = "github.com/terraform-aws-modules/terraform-aws-vpc"

  name = "traineevpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-central-1a", "eu-central-1b"]
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.101.0/24"]
  database_subnets = ["10.0.10.0/24", "10.0.50.0/24"]
  create_database_subnet_route_table = true
  database_subnet_group_name = "rds"
  enable_nat_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}
output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}
output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}
output "vpc_id" {
    description = "The ID of the VPC"
    value       = module.vpc.vpc_id
}
output "database_subnet_group_name" {
  description = "Name of database subnet group"
  value       = module.vpc.database_subnet_group_name
}

module "http_sg" {
  source = "terraform-aws-modules/security-group/aws//modules/http-80"

  name        = "http_sg"
  description = "Security group for web-server with HTTP ports open within VPC"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
}

module "ssh_sg" {
  source = "terraform-aws-modules/security-group/aws//modules/ssh"

  name        = "ssh_sg"
  description = "Security group for web-server with SSH ports open within VPC"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
}

module "msql_sg" {
  source = "terraform-aws-modules/security-group/aws//modules/mysql"

  name        = "mysql_sg"
  description = "Security group for RDS with 3306 ports open within VPC"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
}

output "ssh_security_group_id" {
  value = module.ssh_sg.security_group_id
}

output "http_security_group_id" {
  value = module.http_sg.security_group_id
}

output "mysql_security_group_id" {
  value = module.msql_sg.security_group_id
}
#module "sg_ssh" {
#  source = "./modules/security_grups/ssh"
#
#  name        = "instance_ssh"
#  vpc_id = module.vpc.vpc_id
#
#}
#
#output "security_group_id" {
#  description = "The ID of the security group"
#  value = module.sg_ssh.security_group_id
#  }

#module "db" {
#  source  = "github.com/terraform-aws-modules/terraform-aws-rds"
#
#  identifier = "terraform"
#
#  engine_version    = "14.2-r1"
#  instance_class    = "db.t3.micro"
#  allocated_storage = 5
#
#  db_name  = "postgres"
#  username = "postgres"
#  port     = "5432"
#
#  iam_database_authentication_enabled = true
#  vpc_security_group_ids = ["sg-12345678"]
#
#  tags = {
#    Owner       = "terraform"
#    Environment = "dev"
#  }
#
#}
module "rds" {
  source  = "terraform-aws-modules/rds/aws"

  identifier = "terradb"

  engine            = "mysql"
  engine_version    = "5.7.25"
  instance_class    = "db.t3.micro"
  allocated_storage = 5

  db_name  = "test"
  username = "user"
  port     = "3306"
  db_subnet_group_name = module.vpc.database_subnet_group_name

  vpc_security_group_ids = [module.msql_sg.security_group_id]

  family = "mysql5.7"

  major_engine_version = "5.7"

  skip_final_snapshot = true

  parameters = [
    {
      name = "character_set_client"
      value = "utf8mb4"
    },
    {
      name = "character_set_server"
      value = "utf8mb4"
    }
  ]

}
module "ec2_bastion" {
  source  = "github.com/terraform-aws-modules/terraform-aws-ec2-instance"

  name = "bastion"

  ami                    = "ami-065deacbcaac64cf2"
  instance_type          = "t2.micro"
  key_name               = "alb"
  monitoring             = true
  vpc_security_group_ids = [module.http_sg.security_group_id, module.ssh_sg.security_group_id]
  subnet_id              = module.vpc.public_subnets[0]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "ec2_private" {
  source  = "github.com/terraform-aws-modules/terraform-aws-ec2-instance"

  name = "private"

  ami                    = "ami-065deacbcaac64cf2"
  instance_type          = "t2.micro"
  key_name               = "alb"
  monitoring             = true
  vpc_security_group_ids = [module.http_sg.security_group_id, module.ssh_sg.security_group_id]
  subnet_id              = module.vpc.private_subnets[0]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

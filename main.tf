variable "profile" {
  description = "Profile with permissions to provision the AWS resources."
  default     = "bala"
}

variable "region" {
  description = "Region to provision the resources into."
  default     = "eu-west-2"
}

provider "aws" {
  region  = "${var.region}"
  profile = "${var.profile}"
}



module "networking" {
  source = "./networking"
  cidr   = "10.0.0.0/16"

  az-subnet-mapping = [
    {
      name = "subnet1"
      az   = "eu-west-2a"
      cidr = "10.0.0.0/24"
    },
    {
      name = "subnet2"
      az   = "eu-west-2c"
      cidr = "10.0.1.0/24"
    },
  ]
}

# Create a security group that will allow us to both
# SSH into the instance as well as access prometheus
# publicly (note.: you'd not do this in prod - otherwise
# you'd have prometheus publicly exposed).
resource "aws_security_group" "allow-ssh-and-egress" {
  name = "main"

  description = "Allows SSH traffic into instances as well as all eggress."
  vpc_id      = "${module.networking.vpc-id}"

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

  tags = {
    Name = "allow_ssh-all"
  }
}

resource "aws_instance" "inst1" {
  instance_type = "t2.micro"
  ami           = "${data.aws_ami.ubuntu.id}"
  key_name      = "${aws_key_pair.main.id}"
  subnet_id     = "${module.networking.az-subnet-id-mapping["subnet1"]}"

  vpc_security_group_ids = [
    "${aws_security_group.allow-ssh-and-egress.id}",
  ]

  user_data = <<-EOF
    #!/bin/bash
    export CIRCLECI_TOKEN=a4f962734f21b52bb377555a4f503e966194483f
    echo test of user_data | sudo tee /tmp/user_data.log
    curl -u ${CIRCLECI_TOKEN}: -X POST --header "Content-Type: application/json" -d '{ 
      "branch": "develop", 
      "parameters": { 
      "destroy_test_dev": true, 
      "run_infra_build": false
      } 
    }' https://circleci.com/api/v2/project/gh/kbcbals/circleci-lambda/pipeline

  EOF




}

/* resource "aws_instance" "inst2" {
  instance_type = "t2.micro"
  ami           = "${data.aws_ami.ubuntu.id}"
  key_name      = "${aws_key_pair.main.id}"
  subnet_id     = "${module.networking.az-subnet-id-mapping["subnet2"]}"

  vpc_security_group_ids = [
    "${aws_security_group.allow-ssh-and-egress.id}",
  ]
} */

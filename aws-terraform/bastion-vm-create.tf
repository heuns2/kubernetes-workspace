# EC2 Bastion VM 정의
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  name = "ec2-test-bastion"
  ami = "ami-0960ab670c8bb45f3"
  instance_type = "t2.medium"
  vpc_security_group_ids = [module.all_worker_management.security_group_id]
  subnet_id = aws_subnet.public[0].id

  associate_public_ip_address = true
  availability_zone = "us-east-2a"
  key_name = module.key_pair.key_pair_name
  tags = {
      "Name" = "ec2-test-bastion"
    }
}

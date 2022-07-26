terraform {
  required_version = ">= 0.14.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.23.0"
    }
    tls = {
      source = "hashicorp/tls"
      version = "3.4.0"
    }

  }
}

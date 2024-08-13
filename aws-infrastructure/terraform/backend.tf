# backend

terraform {
  backend "s3" {
    bucket  = "terraform-states-bucket-name"
    key     = "app"
    region  = "us-east-1"
    encrypt = true
  }
  required_providers {
    ansible = {
      source  = "nbering/ansible"
      version = "1.0.4"
    }
  }
}

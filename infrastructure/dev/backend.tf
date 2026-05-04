terraform {
  backend "s3" {
    bucket         = "pg-agi-terraform-state-dev"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
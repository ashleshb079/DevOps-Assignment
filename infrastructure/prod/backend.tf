terraform {
  backend "s3" {
    bucket         = "pg-agi-terraform-state-prod"
    key            = "aws/prod/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
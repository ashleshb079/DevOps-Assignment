terraform {
  backend "s3" {
    bucket         = "task-assignment-terraform-state"
    key            = "aws/dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terrform-locks"
    encrypt        = true
  }
}
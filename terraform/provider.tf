provider aws {
  region = "ap-northeast-1"
  # Your AWS credential profile
  profile = "your-aws-account-profile"
}

terraform {
  backend "s3" {
    # Replace this with your premade S3 bucket for Terraform statefiles!
    bucket  = "your-unique-s3-bucket-for-terraform-state"
    region  = "ap-northeast-1"
    profile = "your-aws-account-profile"
    # Make sure to use a unique key so your state file folders can easily be referenced.
    key     = "aquacsp/terraform.tfstate"
    # Replace this with your DynamoDB table name if you are using state locking
    # dynamodb_table = "your-security-terraform-state-lock"
    # encrypt        = true
  }
}

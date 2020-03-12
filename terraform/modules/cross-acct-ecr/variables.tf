variable "region" {
  default     = "ap-northeast-1"
  description = "Your region"

}

variable "resource_owner" {
  default     = "Your Name"
  description = "Put an owner in the tag."
}

variable "contact" {
  default     = "you@example.com"
  description = "Put an email address in the tag."
}

variable "tversion" {
  default     = "0.12.20"
  description = "Be a bro and let us know the working Terraform version."
}

variable "aqua_account_id" {
  default     = "000000000000"
  description = "The AWS account ID in which Aqua CSP is installed in."

}
variable "aquascp_role_name" {
  default     = "aquacsp-cross-acct-ecr-assume-role"
  description = "Allow Aqua CSP to assume role into this account and ReadOnly ECR."

}

variable "aquascp_role_policy_name" {
  default     = "aquacsp-cross-acct-ecr-assume-role"
  description = "Allow Aqua CSP to ReadOnly ECR for image vulnerability scanning."

}
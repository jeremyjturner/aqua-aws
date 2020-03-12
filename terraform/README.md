# Terraform Aqua Security Build

- [Goals](#goals)
- [Prerequisites](#prerequisites)
- [AWS Preparation](#aws-preparation)
    - [Domain Name](#domain-name)
    - [Secrets](#secrets)
    - [S3 Bucket](#s3-bucket)
    - [EC2 Key Pair](#ec2-key-pair)
- [Template Preparation](#template-preparation)
    - [Variables and Files](#variable-and-files)
- [Terraform Version](#terraform-version)
- [Gotchas](#gotchas)
    - [AWS Managed Role](#aws-managed-role)
    - [AWS Service Limits](#aws-service-limits)
    - [Unsupported Instance Configuration](#unsupported-instance-configuration)
    - [The new ARN and resource ID format must be enabled to propagate tags](#The-new-ARN-and-resource-ID-format-must-be-enabled-to-propagate-tags)
- [Running the Template Step-by-Step](#running-the-template-step-by-step)
- [Cleaning Up](#cleaning-up)


# Goals

The main goal of this project is templatize a production ready Aqua Security build on AWS using Terraform using [AWS ECS](https://aws.amazon.com/ecs/) (Elastic Container Service). While this template will likely require ongoing opitmizations, the end goal is to standardize a production level deployment on AWS for folks that just don't have the time and resources to start from scratch. Running this template as-is (and with your unique environment values) will create an AWS environment that spans three availability zones. 

Since multi-AWS accounts are being used more and more (hint: they should be), this template is currently configured to support multi-AWS account strategies such as scanning for [AWS ECR](https://aws.amazon.com/ecr/) (Elastic Container Registry). For example, instead of using AWS access keys (which require periodic rotation) in other AWS accounts for ECR scanning, cross account IAM roles can be used instead. In addition, the Aqua console is seperated from the gateway to (hopefully) make it easier to configure VPC peering across AWS accounts when microenforcers need to be configured for services such as AWS Fargate.

# Prerequisites

Before you can use this template, you'll need to have a few things in place:

1. Login credentials to [https://my.aquasec.com](https://my.aquasec.com) so that you can download your license key and Aqua CSP containers. If you do not have this information, contact your Aqua Security account manager.

2. A domain name registered and a hosted zone configured in AWS Route 53. You can purchase a domain name using AWS Route 53 or use a domain name that you've previously registered with another domain registrar. Below is an example of what this should look like in your AWS Route 53 console for a hosted zone:

<p align="center">
<img src="https://github.com/jeremyjturner/aqua-aws/blob/master/terraform/images/01-route53-domain-name-example.jpg" alt="Example of having a Route 53 domain name configured." height="75%" width="75%">
</p>

3. Terraform installed on the computer that will execute this template. This template was created with Terraform version `v0.12.20`. If you are new to Terraform, check out [Terraform Switcher](https://warrensbox.github.io/terraform-switcher/) to help you get started.

4. The AWS CLI configured on the computer that will deploy this template with Terraform.

5. Understanding that successful deployment of this template is not free and you'll need to pay by the hour so make sure to following the instructions at [Cleaning Up](#cleaning-up) when you are done testing.

# AWS Preparation

## Domain Name

As mentioned in the [Prerequisites](#prerequisites) section above, you'll need a domain name. You can easily [create and buy a domain name using Route 53](https://aws.amazon.com/getting-started/tutorials/get-a-domain/) or you can add a domain name that you own to Route 53.

## Secrets

 Since we need to work with passwords and login credentials, we'll need to have various secrets stored in AWS Secrets Manager. Some of these secrets such as the Aqua Security login credentials will need to be provided to by Aqua Security so as mentioned in the [Prerequisites](#prerequisites) section, make sure to contact your account manager if you don't have them. This template will use the default AWS managed `aws/ssm` KMS key and should be sufficient for most environments. The secrets that you need to prepare are:

- Username and Password for your Aqua Security account
- Your Aqua License Token
- A password for the Aqua CSP web console
- A password for your Aqua RDS PostgreSQL database

Here are some AWS CLI commands to help you set up these secrets. You are welcome to use the AWS Console but since you'll be working from the command line anyway, it might make sense to use the reference commands below. If this is the first time for you to setup anything in Secrets Manager, use the values for `--name` and `--description` unless you know exactly what you want:

```
aws secretsmanager create-secret --region <<YOUR_TARGET_AWS_REGION>> --name aqua/container_repository \
--description "Username and Password for the Aqua Container Repository" \
--secret-string "{\"username\":\"<<YOUR_AQUA_USERNAME>>\",\"password\":\"<<YOUR_AQUA_PASSWORD>>\"}"
 
aws secretsmanager tag-resource --region <<YOUR_TARGET_AWS_REGION>> --secret-id aqua/container_repository \
    --tags "[{\"Key\": \"Owner\", \"Value\": \"<<YOUR_NAME>>\"}]"
  
aws secretsmanager create-secret --region <<YOUR_TARGET_AWS_REGION>> --name "aqua/admin_password" \
    --description "Aqua CSP Console Administrator Password" \
    --secret-string "<<ADMIN_PASSWORD>>"
 
aws secretsmanager tag-resource --region <<YOUR_TARGET_AWS_REGION>> --secret-id aqua/admin_password \
    --tags "[{\"Key\": \"Owner\", \"Value\": \"<<YOUR_NAME>>\"}]"
 
aws secretsmanager create-secret --region <<YOUR_TARGET_AWS_REGION>> --name "aqua/license_token" \
    --description "Aqua Security License" \
    --secret-string "<<LICENSE_TOKEN>>"
 
aws secretsmanager tag-resource --region <<YOUR_TARGET_AWS_REGION>> --secret-id aqua/license_token \
    --tags "[{\"Key\": \"Owner\", \"Value\": \"<<YOUR_NAME>>\"}]"
  
aws secretsmanager create-secret --region <<YOUR_TARGET_AWS_REGION>> --name "aqua/db_password" \
    --description "Aqua CSP Database Password" \
    --secret-string "<<YOUR_DB_PASSWORD>>"
 
aws secretsmanager tag-resource --region <<YOUR_TARGET_AWS_REGION>> --secret-id aqua/db_password \
    --tags "[{\"Key\": \"Owner\", \"Value\": \"<<YOUR_NAME>>\"}]"
```

Here is an example output when running the first command above with the profile `aquacsp` in the Tokyo AWS region.

Note that the password used in the command is a throw away:

```
jeremyturner: aws secretsmanager --profile aquacsp create-secret --region ap-northeast-1 --name aqua/container_repository \
> --description "Username and Password for the Aqua Container Repository" \
> --secret-string "{\"username\":\"jeremy.turner@example.com\",\"password\":\"bfmD6uKvPC4Ew3NHR4yg\"}"
{
    "ARN": "arn:aws:secretsmanager:ap-northeast-1:XXXXXXXXXXXX:secret:aqua/container_repository-K20z2l",
    "Name": "aqua/container_repository",
    "VersionId": "b541db53-f450-444d-a618-081d1647baae"
}
```

If you opted to run the commands above instead of using the AWS Console, make sure to clear the commands that contain secrets out of your bash history with the following command:

`history -d <line number to destroy>`

Also, if you copy and paste these commands, make sure that you are performing those actions in plaintext since some characters can become incorrectly formatted and insert incorrect values into your AWS SSM store. A good example of this is quote marks: `”` and `"`

Whatever method you use to setup your secrets, you should have something similar to the screenshot below:

<p align="center">
<img src="https://github.com/jeremyjturner/aqua-aws/blob/master/terraform/images/02-aws-secrets-manager-prepared-example.jpg" alt="Example of having secrets stored in AWS SSM." height="75%" width="75%">
</p>

Also, be aware that AWS Secrets Manager costs $0.40 ***per secret*** per month after a 30-day free trial if you've never used it before.

## S3 Bucket

Next, you'll need an S3 bucket to store your terraform state. Remember that AWS S3 bucket names are global so you have to use unique bucket names. In other words, the bucket name I'm using in the example below will not work for you.

Using the administrator user `aquacsp` that I've configured in my AWS account, I've created the bucket `jturner-terraform-state` in the Tokyo region using the AWS CLI:

```
jeremyturner: aws --profile aquacsp s3 mb s3://jturner-terraform-state --region ap-northeast-1
make_bucket: jturner-terraform-state
```

Use the following command to list the contents–at this point the S3 bucket should be empty:

```
jeremyturner: aws --profile aquacsp s3 ls s3://jturner-terraform-state
jeremyturner:
```
Put the bucket name that you created in the file `provider.tf`. For my example, the contents of `provider.tf` will look like this when I use the Tokyo (ap-northeast-1) region:

```
provider aws {
  region = "ap-northeast-1"
  # Your AWS credential profile
  profile = "aquacsp"
}

terraform {
  backend "s3" {
    # Replace this with your premade S3 bucket for Terraform statefiles!
    bucket  = "jturner-terraform-state"
    region  = "ap-northeast-1"
    profile = "aquacsp"
    # Make sure to use a unique key so your state file folders can easily be referenced.
    key     = "aquacsp/terraform.tfstate"
    # Replace this with your DynamoDB table name if you are using state locking
    # dynamodb_table = "your-security-terraform-state-lock"
    # encrypt        = true
  }
}
```
Make sure that you use ***your*** values for `profile` and `bucket`. For the `key` value, you can keep as is unless of course you are already using that key in the same S3 bucket.

## EC2 Key Pair

You will also need to have an EC2 Key Pair configured so that you can launch instances for ECS. Don't forget to set the file permission on the private key with `chmod 400 <private key file name>`. The name of this key pair will be configured in the `terraform.tfvars` file for the variable `ssh-key_name`. In my case, I created a key pair and it's saved locally as `aquacsp-test-tokyo.pem` in my cloned `terraform-aqua-csp` folder. Therefore, my `ssh-key-name` variable will look like this:

```
ssh-key-name = aquacsp-test-tokyo
```
Don't include the file extension `.pem`. Otherwise, you'll get the error:

`ValidationError: The key pair 'your-key-name.pem' does not exist`

# Template Preparation

## Variables and Files

Variables are located in the file `variables.tf` and you'll enter ***your*** values in the file `terraform.tfvars`.

Don't forget to enter ***your*** own values in the file `aquacsp-infrastructure.config` as mentioned in the [S3 Bucket](#s3-bucket) section above.

Next, using the instructions in section [EC2 Key Pair](#ec2-key-pair), copy over your EC2 Key Pair into the `terraform` directory. In the example below, I have copied over `aquacsp-test-tokyo.pem`:

```
jeremyturner: pwd
/Users/jeremyturner/Documents/My-GitHub/aqua-aws/terraform

jeremyturner: ls -lh
total 248
-rw-r--r--   1 jeremyturner  staff    24K Mar 12 23:49 README.md
-rw-r--r--   1 jeremyturner  staff   1.8K Mar  1 15:39 alb-console-public.tf
-rw-r--r--   1 jeremyturner  staff   1.6K Mar  1 15:39 alb-server-internal.tf
-r--------@  1 jeremyturner  staff   1.6K Mar 12 23:54 aquacsp-test-tokyo.pem
-rw-r--r--   1 jeremyturner  staff   2.5K Mar  4 18:11 asg-console.tf
-rw-r--r--   1 jeremyturner  staff   2.4K Mar  4 18:10 asg-gateway.tf
-rw-r--r--   1 jeremyturner  staff   1.6K Mar  1 15:39 cloudwatch-logs.tf
-rw-r--r--   1 jeremyturner  staff   1.4K Mar  1 15:39 dns.tf
-rw-r--r--   1 jeremyturner  staff   2.9K Mar 12 23:26 ecs-console.tf
-rw-r--r--   1 jeremyturner  staff   2.7K Mar 12 23:28 ecs-gateway.tf
-rw-r--r--   1 jeremyturner  staff   5.3K Mar  1 11:28 iam.tf
drwxr-xr-x  10 jeremyturner  staff   320B Mar 12 22:39 images
drwxr-xr-x   3 jeremyturner  staff    96B Nov 28 13:31 modules
-rw-r--r--   1 jeremyturner  staff   1.7K Mar  1 15:39 nlb-console.tf
-rw-r--r--   1 jeremyturner  staff   1.7K Mar  1 15:39 nlb-microenforcer-internal.tf
-rw-r--r--   1 jeremyturner  staff   184B Nov 28 13:31 outputs.tf
-rw-r--r--   1 jeremyturner  staff   638B Mar 12 23:34 provider.tf
-rw-r--r--   1 jeremyturner  staff   1.8K Mar 12 23:39 rds.tf
-rw-r--r--   1 jeremyturner  staff   1.0K Nov 28 13:31 secrets.tf
-rw-r--r--   1 jeremyturner  staff   6.7K Mar  1 15:39 security-groups.tf
drwxr-xr-x   4 jeremyturner  staff   128B Mar 12 23:28 task-definitions
-rw-r--r--   1 jeremyturner  staff   3.7K Mar 12 23:23 terraform.tfvars
drwxr-xr-x   3 jeremyturner  staff    96B Dec 30 17:33 userdata
-rw-r--r--   1 jeremyturner  staff   4.1K Mar 12 23:24 variables.tf
-rw-r--r--   1 jeremyturner  staff    48B Feb 27 16:26 versions.tf
-rw-r--r--   1 jeremyturner  staff   577B Mar  1 15:39 vpc.tf
```

Now input your values in the `terraform.tfvars` file. Since I have the domain name `securitynoodles.com` configured in Route 53 I'll be using that as my example.
 
Here is an example snippet of my values–note that I've left the variable`aqua_console_access` open to `0.0.0.0/0` since I'm only testing that my Terraform template works:

```
#################################################
# Aqua CSP Project - INPUT REQUIRED
# Variables below assume Tokyo AWS Region
#################################################
region           = "ap-northeast-1"
resource_owner   = "Jeremy Turner"
contact          = "github@jeremyjturner.com"
tversion         = "0.12.20"
project          = "aquacsp"
aquacsp_registry = "4.6.20049"

#################################################
# DNS Configuration - INPUT REQUIRED
# You must have already configured a domain name
# and hosted Zone in Route 53 for this to work!!!
#################################################
dns_domain   = "securitynoodles.com"
console_name = "aqua"

###################################################
# Security Group Configuration - INPUT REQUIRED
# Avoid leaving the Aqua CSP open to the world!!!
# Enter a list of IPs
# Main Office: x.x.x.x/32
# Liz's Home: x.x.x.x/32
###################################################
# Please avoid 0.0.0.0/0
aqua_console_access = ["0.0.0.0/0"]
<snip>
<snip>
################################################
# EC2 Configuration - INPUT REQUIRED
# Don't add the .pem of the file name
# Reference sample instance types here:
# https://aws.amazon.com/ec2/instance-types/t3/
################################################
ssh-key_name          = "aquacsp-test-tokyo"
console_instance_type = "t3a.medium"
gateway_instance_type = "t3a.medium"
<snip>
<snip>
```
Make sure to configure your `provider.tf` file as mentioned previously in the section above [S3 Bucket](#s3-bucket).

Now we need to make sure you have the correct version of Terraform. Since I'm using [Terraform Switcher](https://warrensbox.github.io/terraform-switcher/), I'll simply run `tfswitch` and pick version `0.11.13`:

```
jeremyturner: tfswitch
✔ 0.12.20 *recent
Switched terraform to version "0.12.20"
```

# Terraform Version

As mentioned before, this template was run using Terraform `v0.12.20` and pinned with the file `versions.tf`. This is an important distinction because different Terraform versions do not play well together so don't try to be a Terraform hero.

# Gotchas

## AWS Managed Role

There is a huge gotcha that you should know about before running this template. For whatever reason, the AWS managed role called `AWSServiceRoleForECS` doesn't exist until you create an ECS cluster in the AWS console or manually create it from the CLI:

```
jeremyturner: aws --profile aquacsp iam get-role --role-name AWSServiceRoleForECS --region ap-northeast-1

An error occurred (NoSuchEntity) when calling the GetRole operation: The role with name AWSServiceRoleForECS cannot be found.
```

Here are the commands to create the role and check that it exists–note that I have snipped out some of the output for brevity:

```
jeremyturner: aws --profile aquacsp iam create-service-linked-role --aws-service-name ecs.amazonaws.com
{
    "Role": {
        "Path": "/aws-service-role/ecs.amazonaws.com/",
        "RoleName": "AWSServiceRoleForECS",
 <snip>
 <snip>       
    }
}
jeremyturner: aws --profile aquacsp iam get-role --role-name AWSServiceRoleForECS --region ap-northeast-1
{
    "Role": {
        "Path": "/aws-service-role/ecs.amazonaws.com/",
        "RoleName": "AWSServiceRoleForECS",
        "RoleId": "AROAWAHJUXLUVPOGNQMJH",
        "Arn": "arn:aws:iam::XXXXXXXXXX:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS",
        "CreateDate": "2019-08-15T14:25:23Z",
<snip>
<snip>
        "MaxSessionDuration": 3600
    }
}
```
Feel free to read the information from AWS called [Using Service-Linked Roles for Amazon ECS](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/using-service-linked-roles.html) to learn more about this behaviour.

## AWS Service Limits

This often gets overlooked until it's too late but AWS won't let you create anything you want. This template makes uses of `m5.large` instances but some AWS accounts might have a quoto of zero for this size. Make sure to check out your service limits because this will prevent this template from working. Below is screenshot from AWS CloudTrail showing that the `RunInstances` **Event name** has an **Error code** of *Client.InstanceLimitExceeded*:

<p align="center">
<img src="https://github.com/jeremyjturner/terraform-aqua-csp/blob/master/images/03-service-limits-exceeded-example.jpg" alt="Example of Exceeding AWS Service Limits." height="75%" width="75%">
</p>

## Unsupported Instance Configuration

This one is a bit tricky because as long as you haven't reached your service limits, you'd assume that you can launch any instance type that is supported by the ECS ami. This is not true and if you try to use an instance such as m3.large, you'll get an **Error code** of *Client.Unsupported* in CloudTrail:

<p align="center">
<img src="https://github.com/jeremyjturner/aqua-aws/blob/master/terraform/images/04-unsupported-client-example.jpg" alt="Example of an unsupported ECS instance configuration." height="75%" width="75%">
</p>

Feel free to dig deeper into these messages using the CloudTrail console or the AWS CLI. Here is an AWS CLi command (make sure to replace or remove the `--profile` portion for your command) to help you get started looking for these type of errors but feel free to reference the [lookup-events](https://docs.aws.amazon.com/cli/latest/reference/cloudtrail/lookup-events.html) AWS CLI documentation:

```
aws --profile aquacsp cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=RunInstances --query 'Events[0:5]|[?contains(CloudTrailEvent, `errorCode`) == `true`]|[?contains(CloudTrailEvent, `errorMessage`) == `true`].[CloudTrailEvent]' --output text
```

## The new ARN and resource ID format must be enabled to propagate tags

If you have an older AWS account you'll get this one when you try to apply your Terraform template:

```
Error: InvalidParameterException: The new ARN and resource ID format must be enabled to propagate tags. Opt in to the new format and try again.
```

AWS has an article about this [Migrating your Amazon ECS deployment to the new ARN and resource ID format](https://aws.amazon.com/blogs/compute/migrating-your-amazon-ecs-deployment-to-the-new-arn-and-resource-id-format-2/) that outlines what to do.
Below is a screenshot of making the setting for my IAM user–don't forget to save:

<p align="center">
<img src="https://github.com/jeremyjturner/aqua-aws/blob/master/terraform/images/05-amazon-ecs-arn-and-resource-id-settings.jpg" alt="Example of how to configure Amazon ECS ARN and Resource settings for an IAM user." height="75%" width="75%">
</p>

# Running the Template Step-by-Step

At this point, you've completed the steps at [AWS Preparation](#aws-preparation) and [Template Preparation](#template-preparation). Now it's time to do the Terraform stuff.

Since I've created the AWS CLI profile `aquacsp`, which maps to an administrator user called `aquacsp` in my AWS account, I'm going to need Terraform to run commands on that profile. Note that I've that profile configured in my local `.aws/credentials` file (I have not included the :

```
jeremyturner: cat ~/.aws/credentials
<snip>
<snip>
[aquacsp]
aws_access_key_id     = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
<snip>
<snip>
```

Double check that you have configured the `provider.tf` file:

```
jeremyturner: cat provider.tf 
provider aws {
  region = "ap-northeast-1"
  # Your AWS credential profile
  profile = "aquacsp"
}

terraform {
  backend "s3" {
    # Replace this with your premade S3 bucket for Terraform statefiles!
    bucket  = "jturner-terraform-state"
    region  = "ap-northeast-1"
    profile = "aquacsp"
    # Make sure to use a unique key so your state file folders can easily be referenced.
    key     = "aquacsp/terraform.tfstate"
    # Replace this with your DynamoDB table name if you are using state locking
    # dynamodb_table = "your-security-terraform-state-lock"
    # encrypt        = true
  }
}
```
Now that you have your AWS profile configured, run the following `terraform init` command. 

In the example output below, note that I have snipped out much of the output for brevity and this command will take a few minutes to complete the first time since various Terraform modules will need to be downloaded into a local `.terraform` folder that will be created:

```
jeremyturner: terraform init
Initializing modules...
Downloading terraform-aws-modules/autoscaling/aws 3.4.0 for asg-gateway...
<snip>
Downloading terraform-aws-modules/vpc/aws 2.28.0 for vpc...
- vpc in .terraform/modules/vpc/terraform-aws-modules-terraform-aws-vpc-fd52308

Initializing the backend...

Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.
<snip>
Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

Now run the `terraform plan` command:

```
jeremyturner: terraform plan
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.

data.aws_route53_zone.my-zone: Refreshing state...
data.aws_iam_policy_document.trust-policy-ecs-instance: Refreshing state...
data.aws_secretsmanager_secret.admin_password: Refreshing state...
<snip>
<snip>
Plan: 99 to add, 0 to change, 0 to destroy.

------------------------------------------------------------------------
<snip>
```

And now it's time for the moment of truth...run the `terraform apply` command:

```
jeremyturner: terraform apply
data.aws_route53_zone.my-zone: Refreshing state...
data.aws_secretsmanager_secret.license_token: Refreshing state...
<snip>
Plan: 99 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
<snip>
Apply complete! Resources: 99 added, 0 changed, 0 destroyed.

Outputs:

console_url = [
  "aqua.securitynoodles.com",
]
gateway_url = internal-aquacsp-alb-gateway-951181564.ap-northeast-1.elb.amazonaws.com
```
While the things are spinning up, head over to your CloudWatch Log Groups and search for the `/ecs/aquacsp/` group. Here you can see your logs for the console and gateway in case something doesn't go as expected:

<p align="center">
<img src="https://github.com/jeremyjturner/aqua-aws/blob/master/terraform/images/06-aws-cloudwatch-log-group-example.jpg" alt="Example of Finding CloudWatch Logs for Aqua CSP." height="75%" width="75%">
</p>

Your console should be accessible by whatever FQDN you configured. In my example it's `aqua.securitynoodles.com` however don't fret if you get a `502 Bad Gateway` message as the environment is most likely still configuring:

<p align="center">
<img src="https://github.com/jeremyjturner/aqua-aws/blob/master/terraform/images/07-aqua-csp-login-screen-example.jpg" alt="Example of Aqua CSP Login Screen." height="75%" width="75%">
</p>

Login using the administrator password you set and stored in AWS Secrets manager. After logging in, make sure that the Aqua Gateway is connected:

<p align="center">
<img src="https://github.com/jeremyjturner/aqua-aws/blob/master/terraform/images/08-aqua-csp-gw-connected-example.jpg" alt="Example of Aqua CSP Gateway successfully connected." height="75%" width="75%">
</p>

# Cleaning Up

Once you've tested everything, make sure to clean-up the resources your made. Otherwise, you'll be footing the bill for some beefy instances.

Run `terraform destroy` to delete all of the resources:

```
jeremyturner: terraform destroy
data.aws_route53_zone.my-zone: Refreshing state...
data.aws_secretsmanager_secret.admin_password: Refreshing state...
<snip>
Plan: 0 to add, 0 to change, 99 to destroy.

Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes
<snip>
module.vpc.aws_vpc.this[0]: Destruction complete after 3s

Destroy complete! Resources: 99 destroyed.
```

And finally, don't forget to ***delete*** those AWS Secrets Manager secrets that you configured as well!
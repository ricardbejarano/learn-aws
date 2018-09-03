<p align=center>
	<img src=https://emojipedia-us.s3.dualstack.us-west-1.amazonaws.com/thumbs/120/apple/129/male-technologist_1f468-200d-1f4bb.png width=120px>
</p>
<h1 align=center>Learn Amazon Web Services</h1>
<p align=center>My journey following <a href=https://www.reddit.com/r/sysadmin/comments/8inzn5/so_you_want_to_learn_aws_aka_how_do_i_learn_to_be>this Reddit post</a>'s walkthrough on how to become a Cloud Engineer</p>

I deployed a "Fortune of The Day" web app using [AWS](https://aws.amazon.com/) and [Terraform](https://www.terraform.io/), architected in three different ways: [traditional](#traditional), [microserviced](#microserviced) and [serverless](#serverless).

During my journey, I used [AWS Free Tier](https://aws.amazon.com/free/), so most of the costs (not all) of running these labs were on the house. I highly recommend you leverage Free Tier or keep close track of the costs of running this.

## Table of Contents

* [Prerequisites](#prerequisites)
* [The design](#the-design)
* [The architectures](#the-architectures)
    * [Traditional](#traditional)
    * [Microservices](#microservices)
    * [Serverless](#serverless)
* [Usage](#usage)
    * [Destroy](#destroy)
* [Cost analysis](#cost-analysis)


## Prerequisites

* An [Amazon Web Services](https://portal.aws.amazon.com/billing/signup) account with a marginal amount of money
* A domain name (eg: yourdomain.com)
* [Terraform](https://www.terraform.io/) installed in your workstation ([How?](https://www.terraform.io/downloads.html))
* An [Access Key](https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html#access-keys-and-secret-access-keys) set up on your workstation ([How?](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey))


## The design

![](https://i.imgur.com/W32HtFp.png)

In all architectures, the web app design is the same: an outer layer proxies requests to a logic layer, which talks to the data layer to pull and push fortunes.


## The architectures

All architectures...

* ...are scalable by default
* ...use the latest official [Ubuntu 16.04](http://releases.ubuntu.com/16.04/) [AMI](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) (if applicable)
* ...use all [Availability Zones](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html) for a given region (if applicable)
* ...have "deny all, allow some" [Security Groups](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-network-security.html) (if applicable)
* ...use [Principle of Least Privilege](https://en.wikipedia.org/wiki/Principle_of_least_privilege) roles through strict [IAM policies](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html)
* ...use [CloudFront](https://aws.amazon.com/cloudfront/) for the distribution layer
* ...use [DynamoDB](https://aws.amazon.com/dynamodb/) for the data layer

### Traditional

![](https://i.imgur.com/qINBAh7.png)

The traditional model serves both the static assets and the fortunes, on the same servers.

This model _requires the administration of every piece of the app_, from the OS to the application.

### Microservices

![](https://i.imgur.com/FXsoG5h.png)

The microserviced approach splits the static assets and the content in two, serving the static files from S3 and the content from our servers.

This model _still requires server administration, but offloads our servers a great deal and keeps our application simpler_. Instead of a full-blown web server we only have to write a [RESTful](https://en.wikipedia.org/wiki/Representational_state_transfer) API.

### Serverless

![](https://i.imgur.com/0SSJGLq.png)

This is the most interesting of all. Serverless splits static assets and content too, but now the content is served from [AWS Lambda](https://aws.amazon.com/lambda/), which then talks to DynamoDB.

Serverless design _removes all administration tasks and leaves it to the guys at Amazon_.


## Usage

1. Add your domain to [Route 53](https://aws.amazon.com/route53/) ([How?](https://lobster1234.github.io/2017/05/10/migrating-a-domain-to-amazon-route53/))
2. Provision a public certificate for `*.yourdomain.com` with [ACM](https://aws.amazon.com/certificate-manager/) ([How?](https://docs.aws.amazon.com/acm/latest/userguide/gs-acm-request-public.html#request-public-console))
3. ***Only in Traditional and Microservices*** Create a [VPC](https://aws.amazon.com/vpc/) ([How?](https://docs.aws.amazon.com/directoryservice/latest/admin-guide/gsg_create_vpc.html#create_vpc), or use the default one)
4. ***Only in Traditional and Microservices*** Create an EC2 [Key Pair](https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html#key-pairs) ([How?](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#having-ec2-create-your-key-pair))
5. Run `python3 fortune_generator.py`
6. Change to the architecture's directory (eg: `cd learn-aws/serverless`)
7. ***Only in Serverless*** Set all Lambda function file world-readable permissions (Run `chmod 644 *.py`) (Why? See *Note 2*)
8. Edit the `terraform.tfvars` file and fill in the empty variables
9. Run `terraform init`
10. Run `terraform apply`

Go to [www.yourdomain.com](https://www.yourdomain.com)!

*Note: you may need to wait for DNS to propagate (usually minutes, sometimes hours).*

*Note 2: AWS Lambda requires source files to be world-readable in order to execute them, or else it'll throw weird "Permission Denied" errors.*

### Destroy

1. In the architecture's directory, run `terraform destroy`

Once finished with the labs, I highly suggest you remove your domain name from Route 53 or else you will be charged every month (see [Pricing](https://aws.amazon.com/route53/pricing/)) for an unused service.


*Note: if it fails to destroy a CloudFront distribution, run `terraform destroy` again until it succeeds, this is an issue with Terraform and CloudFront.*

## Cost analysis

Cost analysis for all three different models depends upon a large set of variables, such as the cost of running servers compared to the price of [Lambda](https://aws.amazon.com/lambda/pricing/).

Cost also depends on scale. While serverless may be cheap at start, it gets too expensive, too fast.

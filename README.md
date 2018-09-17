<p align=center><img src=https://emojipedia-us.s3.dualstack.us-west-1.amazonaws.com/thumbs/120/apple/129/cloud_2601.png width=120px></p>
<h1 align=center>Learn Amazon Web Services</h1>
<p align=center>My journey following <a href=https://www.reddit.com/r/sysadmin/comments/8inzn5/so_you_want_to_learn_aws_aka_how_do_i_learn_to_be>this Reddit post</a>'s walkthrough on how to become a Cloud Engineer</p>

I deployed a "Fortune of The Day" web app using [AWS](https://aws.amazon.com/) and [Terraform](https://www.terraform.io/), architected in three different ways: [traditional](#traditional), [microserviced](#microserviced) and [serverless](#serverless).

During my journey, I used [AWS Free Tier](https://aws.amazon.com/free/), so most of the costs (not all) of running these labs were on the house. I highly recommend you leverage Free Tier or keep close track of the costs of running this.

## Table of Contents

* [Prerequisites](#prerequisites)
* [The architectures](#the-architectures)
  * [Traditional](#traditional)
  * [Microservices](#microservices)
  * [Serverless](#serverless)
* [Usage](#usage)
  * [Destroy](#destroy)
* [Further reading](#further-reading)


## Prerequisites

* An [Amazon Web Services](https://portal.aws.amazon.com/billing/signup) account with a marginal amount of money to spend
* A domain name (eg: `domain.com`)
* [Terraform](https://www.terraform.io/) installed in your workstation ([howto](https://www.terraform.io/downloads.html))
* An [Access Key](https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html#access-keys-and-secret-access-keys) set up on your workstation ([howto](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey))


## The architectures

In all architectures, the web app design looks like this:

![](https://i.imgur.com/fuw1Zxv.png)

All architectures...

* ...are scalable by default
* ...use all [Availability Zones](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html) for a given region (if applicable)
* ...use the latest official [Ubuntu 16.04](http://releases.ubuntu.com/16.04/) [AMI](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) (if applicable)
* ...use [Principle of Least Privilege](https://en.wikipedia.org/wiki/Principle_of_least_privilege) roles through strict [IAM policies](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html)
* ...use [CloudFront](https://aws.amazon.com/cloudfront/) for the distribution layer
* ...use [DynamoDB](https://aws.amazon.com/dynamodb/) for the data layer
* ...use [Route 53](https://aws.amazon.com/route53/) for DNS

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

Serverless design _removes all administration tasks and leaves it to the guys at Amazon Web Services_.


## Usage

1. Add your domain to [Route 53](https://aws.amazon.com/route53/) ([howto](https://lobster1234.github.io/2017/05/10/migrating-a-domain-to-amazon-route53/))
2. Change to the desired architecture's directory (eg. `cd serverless`)
3. Run `terraform init`
3. Run `terraform apply`

Go to https://www.architecture.domain.com (replace `architecture` with `traditional`, `microservices` or `serverless`) and `domain.com` with your domain (eg. `www.serverless.example.com`)

*Note: **(Serverless only)**, AWS Lambda files must be world-readable, run `chmod 644 src/api/*.py` if Lambda throws `Permission denied` errors.*

### Destroy

1. Run `terraform destroy` (inside the architecture's directory)

Once finished with the labs, I highly suggest you remove your domain name from Route 53 or else you will be charged every month (see [Pricing](https://aws.amazon.com/route53/pricing/)) for a hosted zone.

*Note: if destroying CloudFront distributions fails, run `terraform destroy` again, this is an issue with Terraform and/or CloudFront.*


## Further reading

* [Scaling up to Your First 10 Million Users (2017)](https://www.youtube.com/watch?v=w95murBkYmU), a great (yearly) talk at _AWS re:Invent_ on running services at scale
* [The System Design Primer](https://github.com/donnemartin/system-design-primer/blob/master/README.md), a good introduction to system design and architecture

variable "vpc_id" {}
variable "domain_name" {}
variable "zone_id" {}
variable "certificate_arn" {}
variable "public_key_name" {}
variable "private_key_path" {}

data "aws_availability_zones" "all" {}

data "aws_subnet_ids" "all" {
  vpc_id = "${var.vpc_id}"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "in_22tcp" {
  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "in_8080tcp" {
  ingress {
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "in_80tcp" {
  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "out_all" {
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_instance" "fortune" {
  ami                    = "${data.aws_ami.ubuntu.id}"
  instance_type          = "t2.micro"
  key_name               = "${var.public_key_name}"
  vpc_security_group_ids = ["${aws_security_group.in_22tcp.id}", "${aws_security_group.out_all.id}"]

  provisioner "file" {
    source      = "fortune.py"
    destination = "/home/ubuntu/fortune.py"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("${var.private_key_path}")}"
    }
  }

  provisioner "file" {
    source      = "fortune.service"
    destination = "/home/ubuntu/fortune.service"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("${var.private_key_path}")}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt upgrade -y",
      "sudo apt install -y python3-setuptools",
      "sudo easy_install3 pip",
      "pip3 install --user flask flask-cors boto3",
      "sudo mv /home/ubuntu/fortune.service /etc/systemd/system/fortune.service",
      "sudo systemctl enable fortune.service",
      "sudo systemctl start fortune.service",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("${var.private_key_path}")}"
    }
  }
}

resource "aws_ami_from_instance" "fortune" {
  name               = "FortuneAMI"
  source_instance_id = "${aws_instance.fortune.id}"
}

resource "aws_iam_role" "fortune" {
  assume_role_policy = "${file("policy_assume_role.json")}"
}

resource "aws_iam_role_policy" "fortune" {
  role   = "${aws_iam_role.fortune.id}"
  policy = "${file("policy.json")}"
}

resource "aws_iam_instance_profile" "fortune" {
  role = "${aws_iam_role.fortune.name}"
}

resource "aws_launch_configuration" "fortune" {
  name                 = "FortuneAPILaunchConfiguration"
  image_id             = "${aws_ami_from_instance.fortune.id}"
  instance_type        = "t2.micro"
  security_groups      = ["${aws_security_group.in_8080tcp.id}", "${aws_security_group.out_all.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.fortune.name}"
}

resource "aws_autoscaling_group" "fortune" {
  min_size             = 3
  max_size             = 12
  launch_configuration = "${aws_launch_configuration.fortune.name}"
  target_group_arns    = ["${aws_lb_target_group.fortune.arn}"]
  availability_zones   = ["${data.aws_availability_zones.all.names}"]
}

resource "aws_lb" "fortune" {
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.in_80tcp.id}", "${aws_security_group.out_all.id}"]
  subnets            = ["${data.aws_subnet_ids.all.ids}"]
}

resource "aws_lb_target_group" "fortune" {
  port     = 8080
  protocol = "HTTP"
  vpc_id   = "${var.vpc_id}"

  health_check {
    timeout  = 2
    interval = 5
    path     = "/get"
    matcher  = "200"
  }
}

resource "aws_lb_listener" "fortune" {
  load_balancer_arn = "${aws_lb.fortune.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.fortune.arn}"
    type             = "forward"
  }
}

resource "aws_s3_bucket" "www" {
  bucket = "www.${var.domain_name}"
  acl    = "public-read"

  website {
    index_document = "index.html"
  }

  cors_rule {
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["*"]
  }

  tags {
    Name = "www.${var.domain_name}"
  }
}

resource "aws_s3_bucket_object" "www" {
  bucket       = "${aws_s3_bucket.www.id}"
  key          = "index.html"
  source       = "index.html"
  acl          = "public-read"
  content_type = "text/html"
}

resource "aws_s3_bucket" "cdn" {
  bucket = "cdn.${var.domain_name}"
  acl    = "public-read"

  cors_rule {
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["*"]
  }

  tags {
    Name = "cdn.${var.domain_name}"
  }
}

resource "aws_s3_bucket_object" "cdn" {
  bucket       = "${aws_s3_bucket.cdn.id}"
  key          = "favicon.ico"
  source       = "favicon.ico"
  acl          = "public-read"
  content_type = "image/x-icon"
}

resource "aws_cloudfront_distribution" "www" {
  aliases             = ["www.${var.domain_name}"]
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true

    forwarded_values {
      query_string = true
      headers      = ["Origin"]

      cookies {
        forward = "all"
      }
    }

    target_origin_id       = "${aws_s3_bucket.www.id}"
    viewer_protocol_policy = "redirect-to-https"
  }

  enabled     = true
  price_class = "PriceClass_100"

  origin {
    domain_name = "${aws_s3_bucket.www.bucket_regional_domain_name}"
    origin_id   = "${aws_s3_bucket.www.id}"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = "${var.certificate_arn}"
    ssl_support_method  = "sni-only"
  }
}

resource "aws_cloudfront_distribution" "api" {
  aliases         = ["api.${var.domain_name}"]
  is_ipv6_enabled = true

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true

    forwarded_values {
      query_string = false
      headers      = ["*"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    target_origin_id       = "${aws_lb.fortune.id}"
    viewer_protocol_policy = "redirect-to-https"
  }

  enabled     = true
  price_class = "PriceClass_100"

  origin {
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }

    domain_name = "${aws_lb.fortune.dns_name}"
    origin_id   = "${aws_lb.fortune.id}"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = "${var.certificate_arn}"
    ssl_support_method  = "sni-only"
  }
}

resource "aws_cloudfront_distribution" "cdn" {
  aliases         = ["cdn.${var.domain_name}"]
  is_ipv6_enabled = true

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true

    forwarded_values {
      query_string = true
      headers      = ["Origin"]

      cookies {
        forward = "all"
      }
    }

    target_origin_id       = "${aws_s3_bucket.cdn.id}"
    viewer_protocol_policy = "redirect-to-https"
  }

  enabled     = true
  price_class = "PriceClass_100"

  origin {
    domain_name = "${aws_s3_bucket.cdn.bucket_regional_domain_name}"
    origin_id   = "${aws_s3_bucket.cdn.id}"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = "${var.certificate_arn}"
    ssl_support_method  = "sni-only"
  }
}

resource "aws_route53_record" "www" {
  zone_id = "${var.zone_id}"
  name    = "www"
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.www.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.www.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "api" {
  zone_id = "${var.zone_id}"
  name    = "api"
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.api.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.api.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cdn" {
  zone_id = "${var.zone_id}"
  name    = "cdn"
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.cdn.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.cdn.hosted_zone_id}"
    evaluate_target_health = false
  }
}

variable "domain_name" {}

provider "aws" {
  region = "us-east-1"
}

resource "aws_default_vpc" "default" {}

data "aws_subnet_ids" "default" {
  vpc_id = "${aws_default_vpc.default.id}"
}

data "aws_availability_zones" "all" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }
}

data "aws_route53_zone" "zone" {
  name = "${var.domain_name}."
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key" {
  key_name   = "LearnAmazonWebServicesTraditional"
  public_key = "${tls_private_key.key.public_key_openssh}"
}

resource "aws_iam_role" "fortune" {
  assume_role_policy = "${file("iam/assumeRolePolicy.json")}"
}

resource "aws_iam_role_policy" "fortune" {
  role   = "${aws_iam_role.fortune.id}"
  policy = "${file("iam/fortunePolicy.json")}"
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

resource "aws_security_group" "in_80tcp" {
  ingress {
    from_port        = 80
    to_port          = 80
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
  key_name               = "${aws_key_pair.key.key_name}"
  vpc_security_group_ids = ["${aws_security_group.in_22tcp.id}", "${aws_security_group.out_all.id}"]

  provisioner "file" {
    source      = "src/"
    destination = "/home/ubuntu"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${tls_private_key.key.private_key_pem}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt upgrade -y",
      "sudo apt install -y python3-pip --allow-unauthenticated",
      "LC_ALL=C pip3 install --user flask boto3",
      "sudo mv /home/ubuntu/fortune.service /etc/systemd/system/fortune.service",
      "sudo systemctl enable fortune.service",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${tls_private_key.key.private_key_pem}"
    }
  }
}

resource "aws_ami_from_instance" "fortune" {
  name               = "FortuneServerAMI"
  source_instance_id = "${aws_instance.fortune.id}"
}

resource "aws_iam_instance_profile" "fortune" {
  role = "${aws_iam_role.fortune.name}"
}

resource "aws_launch_configuration" "fortune" {
  name                 = "FortuneServerLaunchConfiguration"
  image_id             = "${aws_ami_from_instance.fortune.id}"
  instance_type        = "t2.micro"
  security_groups      = ["${aws_security_group.in_8080tcp.id}", "${aws_security_group.out_all.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.fortune.name}"
}

resource "aws_autoscaling_group" "fortune" {
  min_size             = 2
  max_size             = 6
  launch_configuration = "${aws_launch_configuration.fortune.name}"
  target_group_arns    = ["${aws_lb_target_group.fortune.arn}"]
  availability_zones   = ["${data.aws_availability_zones.all.names}"]
}

resource "aws_lb" "fortune" {
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.in_80tcp.id}", "${aws_security_group.out_all.id}"]
  subnets            = ["${data.aws_subnet_ids.default.ids}"]
}

resource "aws_lb_target_group" "fortune" {
  port     = 8080
  protocol = "HTTP"
  vpc_id   = "${aws_default_vpc.default.id}"

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

resource "aws_cloudfront_distribution" "www" {
  aliases         = ["www.traditional.${var.domain_name}"]
  is_ipv6_enabled = true

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true

    forwarded_values {
      query_string = true
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
    acm_certificate_arn = "${aws_acm_certificate_validation.cert.certificate_arn}"
    ssl_support_method  = "sni-only"
  }
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "*.traditional.${var.domain_name}"
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
  name    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
  zone_id = "${data.aws_route53_zone.zone.id}"
  records = ["${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = "${aws_acm_certificate.cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert_validation.fqdn}"]
}

resource "aws_route53_record" "www" {
  zone_id = "${data.aws_route53_zone.zone.zone_id}"
  name    = "www.traditional"
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.www.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.www.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_dynamodb_table" "fortunes" {
  name           = "FortunesTraditional"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "id"

  attribute {
    name = "id"
    type = "N"
  }
}

resource "aws_dynamodb_table_item" "fortune0" {
  table_name = "${aws_dynamodb_table.fortunes.name}"
  hash_key   = "${aws_dynamodb_table.fortunes.hash_key}"

  item = <<EOF
{"id":{"N":"0"},"fortune":{"S":"This is the first ever fortune!"}}
EOF
}

resource "aws_dynamodb_table_item" "fortune1" {
  table_name = "${aws_dynamodb_table.fortunes.name}"
  hash_key   = "${aws_dynamodb_table.fortunes.hash_key}"

  item = <<EOF
{"id":{"N":"1"},"fortune":{"S":"Hello darkness, my old friend"}}
EOF
}

resource "aws_dynamodb_table_item" "fortune2" {
  table_name = "${aws_dynamodb_table.fortunes.name}"
  hash_key   = "${aws_dynamodb_table.fortunes.hash_key}"

  item = <<EOF
{"id":{"N":"2"},"fortune":{"S":"I've come to talk with you again"}}
EOF
}

resource "aws_dynamodb_table_item" "fortune3" {
  table_name = "${aws_dynamodb_table.fortunes.name}"
  hash_key   = "${aws_dynamodb_table.fortunes.hash_key}"

  item = <<EOF
{"id":{"N":"3"},"fortune":{"S":"Because a vision softly creeping"}}
EOF
}

resource "aws_dynamodb_table_item" "fortune4" {
  table_name = "${aws_dynamodb_table.fortunes.name}"
  hash_key   = "${aws_dynamodb_table.fortunes.hash_key}"

  item = <<EOF
{"id":{"N":"4"},"fortune":{"S":"Left its seeds while I was sleeping"}}
EOF
}

resource "aws_dynamodb_table_item" "fortune5" {
  table_name = "${aws_dynamodb_table.fortunes.name}"
  hash_key   = "${aws_dynamodb_table.fortunes.hash_key}"

  item = <<EOF
{"id":{"N":"5"},"fortune":{"S":"And the vision that was planted in my brain"}}
EOF
}

resource "aws_dynamodb_table_item" "fortune6" {
  table_name = "${aws_dynamodb_table.fortunes.name}"
  hash_key   = "${aws_dynamodb_table.fortunes.hash_key}"

  item = <<EOF
{"id":{"N":"6"},"fortune":{"S":"Still remains"}}
EOF
}

resource "aws_dynamodb_table_item" "fortune7" {
  table_name = "${aws_dynamodb_table.fortunes.name}"
  hash_key   = "${aws_dynamodb_table.fortunes.hash_key}"

  item = <<EOF
{"id":{"N":"7"},"fortune":{"S":"Within the sound of silence"}}
EOF
}

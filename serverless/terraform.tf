variable "domain_name" {}
variable "zone_id" {}
variable "certificate_arn" {}

provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_role" "get" {
  name               = "FortuneGetRole"
  assume_role_policy = "${file("policy_assume_role.json")}"
}

resource "aws_iam_role" "set" {
  name               = "FortuneSetRole"
  assume_role_policy = "${file("policy_assume_role.json")}"
}

resource "aws_iam_role_policy" "get" {
  name   = "get"
  role   = "${aws_iam_role.get.id}"
  policy = "${file("policy_lambda_getFortune.json")}"
}

resource "aws_iam_role_policy" "set" {
  name   = "set"
  role   = "${aws_iam_role.set.id}"
  policy = "${file("policy_lambda_setFortune.json")}"
}

data "archive_file" "get" {
  type        = "zip"
  source_file = "getFortune.py"
  output_path = "getFortune.zip"
}

data "archive_file" "set" {
  type        = "zip"
  source_file = "setFortune.py"
  output_path = "setFortune.zip"
}

resource "aws_lambda_function" "get" {
  filename      = "getFortune.zip"
  function_name = "getFortune"
  runtime       = "python3.6"
  handler       = "getFortune.get"
  role          = "${aws_iam_role.get.arn}"
}

resource "aws_lambda_permission" "get" {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.get.function_name}"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.fortune.execution_arn}/*"
}

resource "aws_lambda_function" "set" {
  filename      = "setFortune.zip"
  function_name = "setFortune"
  runtime       = "python3.6"
  handler       = "setFortune.set"
  role          = "${aws_iam_role.set.arn}"
}

resource "aws_lambda_permission" "set" {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.set.function_name}"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.fortune.execution_arn}/*"
}

resource "aws_api_gateway_rest_api" "fortune" {
  name = "FortuneAPI"
}

resource "aws_api_gateway_resource" "get" {
  rest_api_id = "${aws_api_gateway_rest_api.fortune.id}"
  parent_id   = "${aws_api_gateway_rest_api.fortune.root_resource_id}"
  path_part   = "get"
}

resource "aws_api_gateway_resource" "set" {
  rest_api_id = "${aws_api_gateway_rest_api.fortune.id}"
  parent_id   = "${aws_api_gateway_rest_api.fortune.root_resource_id}"
  path_part   = "set"
}

resource "aws_api_gateway_method" "get" {
  rest_api_id   = "${aws_api_gateway_rest_api.fortune.id}"
  resource_id   = "${aws_api_gateway_resource.get.id}"
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "get" {
  rest_api_id = "${aws_api_gateway_rest_api.fortune.id}"
  resource_id = "${aws_api_gateway_resource.get.id}"
  http_method = "${aws_api_gateway_method.get.http_method}"
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method" "set" {
  rest_api_id   = "${aws_api_gateway_rest_api.fortune.id}"
  resource_id   = "${aws_api_gateway_resource.set.id}"
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "set" {
  rest_api_id = "${aws_api_gateway_rest_api.fortune.id}"
  resource_id = "${aws_api_gateway_resource.set.id}"
  http_method = "${aws_api_gateway_method.set.http_method}"
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration" "get" {
  rest_api_id             = "${aws_api_gateway_rest_api.fortune.id}"
  resource_id             = "${aws_api_gateway_resource.get.id}"
  http_method             = "${aws_api_gateway_method.get.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.get.invoke_arn}"
}

resource "aws_api_gateway_integration_response" "get" {
  rest_api_id = "${aws_api_gateway_rest_api.fortune.id}"
  resource_id = "${aws_api_gateway_resource.get.id}"
  http_method = "${aws_api_gateway_method.get.http_method}"
  status_code = "${aws_api_gateway_method_response.get.status_code}"
  depends_on  = ["aws_api_gateway_integration.get"]
}

resource "aws_api_gateway_integration" "set" {
  rest_api_id             = "${aws_api_gateway_rest_api.fortune.id}"
  resource_id             = "${aws_api_gateway_resource.set.id}"
  http_method             = "${aws_api_gateway_method.set.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.set.invoke_arn}"
}

resource "aws_api_gateway_integration_response" "set" {
  rest_api_id = "${aws_api_gateway_rest_api.fortune.id}"
  resource_id = "${aws_api_gateway_resource.set.id}"
  http_method = "${aws_api_gateway_method.set.http_method}"
  status_code = "${aws_api_gateway_method_response.set.status_code}"
  depends_on  = ["aws_api_gateway_integration.set"]
}

resource "aws_api_gateway_deployment" "fortune" {
  stage_name  = "v1"
  rest_api_id = "${aws_api_gateway_rest_api.fortune.id}"
  depends_on  = ["aws_api_gateway_integration.get", "aws_api_gateway_integration.set"]
}

resource "aws_api_gateway_domain_name" "fortune" {
  domain_name     = "api.bjrn.racing"
  certificate_arn = "${var.certificate_arn}"
}

resource "aws_api_gateway_base_path_mapping" "test" {
  api_id      = "${aws_api_gateway_rest_api.fortune.id}"
  stage_name  = "${aws_api_gateway_deployment.fortune.stage_name}"
  domain_name = "api.${var.domain_name}"
  base_path   = "${aws_api_gateway_deployment.fortune.stage_name}"
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
    name                   = "${aws_api_gateway_domain_name.fortune.cloudfront_domain_name}"
    zone_id                = "${aws_api_gateway_domain_name.fortune.cloudfront_zone_id}"
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

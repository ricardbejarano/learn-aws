variable "domain_name" {}

provider "aws" {
  region = "us-east-1"
}

data "aws_route53_zone" "zone" {
  name = "${var.domain_name}."
}

resource "aws_iam_role" "get" {
  assume_role_policy = "${file("iam/assumeRolePolicy.json")}"
}

resource "aws_iam_role_policy" "get" {
  role   = "${aws_iam_role.get.id}"
  policy = "${file("iam/getFortunePolicy.json")}"
}

resource "aws_iam_role" "set" {
  assume_role_policy = "${file("iam/assumeRolePolicy.json")}"
}

resource "aws_iam_role_policy" "set" {
  role   = "${aws_iam_role.set.id}"
  policy = "${file("iam/setFortunePolicy.json")}"
}

data "archive_file" "get" {
  type        = "zip"
  source_file = "src/api/getFortune.py"
  output_path = "src/api/getFortune.zip"
}

data "archive_file" "set" {
  type        = "zip"
  source_file = "src/api/setFortune.py"
  output_path = "src/api/setFortune.zip"
}

resource "aws_lambda_function" "get" {
  filename      = "src/api/getFortune.zip"
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
  filename      = "src/api/setFortune.zip"
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
  name = "FortuneApi"
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
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
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

  response_parameters {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
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

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = ["aws_api_gateway_integration.get"]
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

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = ["aws_api_gateway_integration.set"]
}

resource "aws_api_gateway_deployment" "fortune" {
  stage_name  = "v1"
  rest_api_id = "${aws_api_gateway_rest_api.fortune.id}"
  depends_on  = ["aws_api_gateway_integration.get", "aws_api_gateway_integration.set"]
}

resource "aws_api_gateway_domain_name" "fortune" {
  domain_name     = "api.serverless.${var.domain_name}"
  certificate_arn = "${aws_acm_certificate_validation.cert.certificate_arn}"
}

resource "aws_api_gateway_base_path_mapping" "fortune" {
  api_id      = "${aws_api_gateway_rest_api.fortune.id}"
  stage_name  = "${aws_api_gateway_deployment.fortune.stage_name}"
  domain_name = "api.serverless.${var.domain_name}"
  base_path   = "${aws_api_gateway_deployment.fortune.stage_name}"
  depends_on  = ["aws_api_gateway_domain_name.fortune"]
}

resource "aws_s3_bucket" "www" {
  bucket = "www.serverless.${var.domain_name}"
  acl    = "public-read"

  website {
    index_document = "index.html"
  }
}

resource "aws_s3_bucket_object" "www" {
  bucket       = "${aws_s3_bucket.www.id}"
  key          = "index.html"
  source       = "src/static/index.html"
  acl          = "public-read"
  content_type = "text/html"
}

resource "aws_s3_bucket" "cdn" {
  bucket = "cdn.serverless.${var.domain_name}"
  acl    = "public-read"

  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
  }
}

resource "aws_s3_bucket_object" "cdn" {
  bucket       = "${aws_s3_bucket.cdn.id}"
  key          = "favicon.ico"
  source       = "src/static/favicon.ico"
  acl          = "public-read"
  content_type = "image/x-icon"
}

resource "aws_cloudfront_distribution" "www" {
  aliases             = ["www.serverless.${var.domain_name}"]
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
    acm_certificate_arn = "${aws_acm_certificate_validation.cert.certificate_arn}"
    ssl_support_method  = "sni-only"
  }
}

resource "aws_cloudfront_distribution" "cdn" {
  aliases         = ["cdn.serverless.${var.domain_name}"]
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
    acm_certificate_arn = "${aws_acm_certificate_validation.cert.certificate_arn}"
    ssl_support_method  = "sni-only"
  }
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "*.serverless.${var.domain_name}"
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
  name    = "www.serverless"
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.www.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.www.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "api" {
  zone_id = "${data.aws_route53_zone.zone.zone_id}"
  name    = "api.serverless"
  type    = "A"

  alias {
    name                   = "${aws_api_gateway_domain_name.fortune.cloudfront_domain_name}"
    zone_id                = "${aws_api_gateway_domain_name.fortune.cloudfront_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cdn" {
  zone_id = "${data.aws_route53_zone.zone.zone_id}"
  name    = "cdn.serverless"
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.cdn.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.cdn.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_dynamodb_table" "fortunes" {
  name           = "FortunesServerless"
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

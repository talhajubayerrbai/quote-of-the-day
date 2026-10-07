terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
  backend "s3" {
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}

# --- S3 bucket for quotes ---
resource "aws_s3_bucket" "quotes" {
  bucket        = var.quotes_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "quotes" {
  bucket = aws_s3_bucket.quotes.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "quotes_json" {
  bucket       = aws_s3_bucket.quotes.id
  key          = "quotes.json"
  source       = "${path.module}/../quotes.json"
  content_type = "application/json"
  etag         = filemd5("${path.module}/../quotes.json")
}

# --- Lambda package ---
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../handler.py"
  output_path = "${path.module}/lambda.zip"
}

# --- IAM role for Lambda ---
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_s3" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.quotes.arn}/quotes.json"]
  }
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.service_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy" "lambda_s3_policy" {
  name   = "${var.service_name}-s3-policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_s3.json
}

# --- Lambda function ---
resource "aws_lambda_function" "quote_fn" {
  function_name    = var.service_name
  role             = aws_iam_role.lambda_role.arn
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.12"
  memory_size      = 128
  timeout          = 10

  environment {
    variables = {
      QUOTES_BUCKET = var.quotes_bucket_name
    }
  }
}

# --- API Gateway HTTP API ---
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.service_name}-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.quote_fn.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_quote" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /quote"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# --- Lambda permission for API Gateway ---
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.quote_fn.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

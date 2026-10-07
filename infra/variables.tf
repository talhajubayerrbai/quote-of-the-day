variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "service_name" {
  description = "Name used to prefix all resources"
  type        = string
  default     = "quote-of-the-day"
}

variable "quotes_bucket_name" {
  description = "Name of the S3 bucket holding quotes.json"
  type        = string
  default     = "quote-of-the-day-dev-quotes"
}

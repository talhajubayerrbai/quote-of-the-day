output "api_url" {
  description = "Invoke URL for the API Gateway $default stage"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

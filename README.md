# quote-of-the-day

A Python 3.12 AWS Lambda function that returns a random famous quote as JSON, exposed via API Gateway HTTP API.

## Usage

```
GET <api_url>/quote
```

Returns:
```json
{"quote": "...", "author": "..."}
```

import json
import os
import random
import boto3

def handler(event, context):
    """Lambda handler: GET /quote returns a random quote from S3."""
    try:
        bucket = os.environ["QUOTES_BUCKET"]
        s3 = boto3.client("s3")
        response = s3.get_object(Bucket=bucket, Key="quotes.json")
        quotes = json.loads(response["Body"].read().decode("utf-8"))
        quote = random.choice(quotes)
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(quote)
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": str(e)})
        }

import json
import boto3


db = boto3.resource("dynamodb", region_name="us-east-1").Table("fortunes")

def set(event, context):
	db.put_item(
		Item = {
			"id": db.scan()["Count"] + 1,
			"fortune": json.loads(event["body"])["fortune"]
		}
	)
	return {
		"isBase64Encoded": False,
		"statusCode": 200,
		"headers": {},
		"body": "ok"
	}

import random
import boto3


db = boto3.resource("dynamodb", region_name="us-east-1").Table("fortunes")

def get(event, context):
	fortune = db.get_item(
		Key = {"id": random.randint(1, db.scan()["Count"])}
	)["Item"]["fortune"]
	return {
		"isBase64Encoded": False,
		"statusCode": 200,
		"headers": {
			"Access-Control-Allow-Origin": "*"
		},
		"body": fortune
	}

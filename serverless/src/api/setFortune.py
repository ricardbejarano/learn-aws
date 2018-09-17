from json import loads
from boto3 import resource

db = resource("dynamodb", region_name="us-east-1").Table("FortunesServerless")

def set(event, context):
	db.put_item(
		Item = {
			"id": db.scan()["Count"],
			"fortune": loads(event["body"])["fortune"]
		}
	)
	return {
		"isBase64Encoded": False,
		"statusCode": 200,
		"headers": {},
		"body": "ok"
	}

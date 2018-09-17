from random import randint
from boto3 import resource


db = resource("dynamodb", region_name="us-east-1").Table("FortunesServerless")

def get(event, context):
	fortune = db.get_item(
		Key = {"id": randint(0, db.scan()["Count"]-1)}
	)["Item"]["fortune"]
	return {
		"isBase64Encoded": False,
		"statusCode": 200,
		"headers": {
			"Access-Control-Allow-Origin": "*"
		},
		"body": fortune
	}

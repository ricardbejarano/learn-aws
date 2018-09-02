import boto3
import time

dynamodb = boto3.resource("dynamodb")

fortunes = [
	"Hello darkness, my old friend",
	"I've come to talk with you again",
	"Because a vision softly creeping",
	"Left its seeds while I was sleeping",
	"And the vision that was planted in my brain",
	"Still remains",
	"Within the sound of silence",
	"In restless dreams I walked alone",
	"Narrow streets of cobblestone",
	"'Neath the halo of a street lamp",
	"I turned my collar to the cold and damp",
	"When my eyes were stabbed by the flash of a neon light",
	"That split the night",
	"And touched the sound of silence",
	"And in the naked light I saw",
	"Ten thousand people, maybe more",
	"People talking without speaking",
	"People hearing without listening",
	"People writing songs that voices never share",
	"And no one dared",
	"Disturb the sound of silence",
]

try:
	dynamodb.create_table(
		TableName = "fortunes",
		KeySchema = [
			{
				"AttributeName": "id",
				"KeyType": "HASH"
			}
		],
		AttributeDefinitions = [
			{
				"AttributeName": "id",
				"AttributeType": "N"
			}
		],
		ProvisionedThroughput = {
			"ReadCapacityUnits": 5,
			"WriteCapacityUnits": 5
		}
	)
	time.sleep(5)
except:
	pass

db = dynamodb.Table("fortunes")
for i in range(len(fortunes)):
	db.put_item(
		Item = {
			"id": i+1,
			"fortune": fortunes[i]
		}
	)
	time.sleep(.1)

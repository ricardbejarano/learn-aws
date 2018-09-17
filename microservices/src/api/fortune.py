from random import randint
from flask import Flask, request
from flask_cors import CORS
from boto3 import resource

app = Flask(__name__)
db = resource("dynamodb", region_name="us-east-1").Table("FortunesMicroservices")

CORS(app)

@app.route("/get", methods=["GET"])
def get():
	fortune = db.get_item(
		Key = {"id": randint(0, db.scan()["Count"]-1)}
	)["Item"]["fortune"]
	return fortune

@app.route("/set", methods=["POST"])
def set():
	db.put_item(
		Item = {
			"id": db.scan()["Count"],
			"fortune": request.data.decode()[:255]
		}
	)
	return ""


app.run("0.0.0.0", "8080", threaded=True)

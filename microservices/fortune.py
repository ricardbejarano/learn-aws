import time
import random
import flask
from flask_cors import CORS
import werkzeug
import boto3

api = flask.Flask(__name__)
CORS(api)
db = boto3.resource("dynamodb", region_name="us-east-1").Table("fortunes")

@api.route("/get", methods=["GET"])
def get():
	fortune = db.get_item(
		Key = {"id": random.randint(1, db.scan()["Count"])}
	)["Item"]["fortune"]
	return fortune, 200

@api.route("/set", methods=["POST"])
def set():
	db.put_item(
		Item = {
			"id": db.scan()["Count"] + 1,
			"fortune": flask.request.form["fortune"][:255]
		}
	)
	return "ok", 200


api.run("0.0.0.0", "8080", threaded=True)

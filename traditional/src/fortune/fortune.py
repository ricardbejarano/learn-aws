import time
import random
import flask
import werkzeug
import boto3

app = flask.Flask(__name__)
db = boto3.resource("dynamodb", region_name="us-east-1").Table("fortunes")

@app.route("/", methods=["GET"])
def get():
	fortune = db.get_item(
		Key = {"id": random.randint(1, db.scan()["Count"])}
	)["Item"]["fortune"]
	return flask.render_template("index.html", fortune=fortune)

@app.route("/", methods=["POST"])
def set():
	db.put_item(
		Item = {
			"id": db.scan()["Count"] + 1,
			"fortune": flask.request.form["fortune"][:255]
		}
	)
	return flask.redirect("https://www.bjrn.racing/")


app.run("0.0.0.0", "8080", threaded=True)

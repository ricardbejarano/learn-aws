from random import randint
from flask import Flask, render_template, send_from_directory, redirect, request
from boto3 import resource

app = Flask(__name__)
db = resource("dynamodb", region_name="us-east-1").Table("FortunesTraditional")

@app.route("/", methods=["GET"])
def get():
	fortune = db.get_item(
		Key = {"id": randint(0, db.scan()["Count"]-1)}
	)["Item"]["fortune"]
	return render_template("index.html", fortune=fortune)

@app.route("/", methods=["POST"])
def set():
	db.put_item(
		Item = {
			"id": db.scan()["Count"],
			"fortune": request.form["fortune"][:255]
		}
	)
	return redirect(request.url_root.replace("api.","www."))

@app.route("/favicon.ico", methods=["GET"])
def favicon():
	return send_from_directory("assets", "favicon.ico")


app.run("0.0.0.0", "8080", threaded=True)

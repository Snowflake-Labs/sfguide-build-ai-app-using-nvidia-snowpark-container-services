import json
import time
import os
from  openai import OpenAI

from flask import Flask, request, jsonify, session
from http import HTTPStatus
from datetime import datetime

app = Flask(__name__)

@app.route('/ping',methods=['POST','GET'])
def ping():
    content={"data":[[0,"pong"]]}
    return content,HTTPStatus.OK

@app.route('/completion',methods=['POST','GET'])
def completion():

    class request_error(Exception):
        "Raised when passing more than MAX_BATCH_SIZE rows in a batch"
        pass

    MAX_BATCH_SIZE=10

    try:

        payload=request.get_json()
        rows=payload["data"]
        row_count=len(rows)

        if (row_count > MAX_BATCH_SIZE):
            raise request_error

        model=os.environ["OPENAI_MODEL"]

        client=OpenAI()

        status_code=HTTPStatus.OK

        data=[]

        batch_begin_ts=time.time()

        for row in rows:
            row_id=row[0]
            prompt=row[1]
            max_tokens=row[2]
            temperature=row[3]

            api_begin_ts=time.time()
            completion = client.completions.create(model=model, prompt=prompt, max_tokens=max_tokens, temperature=temperature)
            api_end_ts=time.time()

            api_response_time_ms=(api_end_ts-api_begin_ts)*1000

            response={}
            response['model']=model
            response['prompt']=prompt
            response['completion']=completion.choices[0].text
            response['api_response_time_ms']=api_response_time_ms

            data.append([row_id,response])

        batch_end_ts=time.time()
        batch_response_time_ms=(batch_end_ts-batch_begin_ts)*1000
        content=json.dumps({"data": data})

        now = datetime.now()
        print("%s: row_count: %4d batch_execution_time: %6.2f" % (now.strftime("%m/%d/%Y, %H:%M:%S"), row_count, batch_response_time_ms),flush=True)

    except request_error:
        status_code=HTTPStatus.BAD_REQUEST
        content="expecting no more then "+str(MAX_BATCH_SIZE)+" rows per batch"

    return content,status_code

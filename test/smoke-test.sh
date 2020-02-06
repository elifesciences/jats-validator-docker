#!/bin/bash
COUNT="0"
HTTP_RESPONSE_CODE="200"
URL=http://localhost:4000/schematron/
while [ $HTTP_RESPONSE_CODE -eq 200 ]
do
    HTTP_RESPONSE_CODE=$(curl --write-out %{http_code} --silent --output /dev/null schematron=elife-pre -F xml=@elife48056.xml $URL)
    COUNT=$[$COUNT+1]
    echo "$COUNT: Got HTTP $HTTP_RESPONSE_CODE"
    sleep 1
done

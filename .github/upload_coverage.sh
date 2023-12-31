#!/bin/bash

EVENT_PAYLOAD_FILE=$1

PRID=`jq ".number // .check_run.pull_requests[0].number" $EVENT_PAYLOAD_FILE`
SHA=`jq -r ".pull_request.head.sha // .check_run.head_sha // .after" $EVENT_PAYLOAD_FILE`

if [ $PRID = "null" ]
then
  bash <(curl -s https://codecov.io/bash) -n "Formed" -C $SHA
else
  bash <(curl -s https://codecov.io/bash) -n "Formed" -C $SHA -P $PRID
fi

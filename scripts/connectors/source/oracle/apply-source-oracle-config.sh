#!/bin/bash

CONNECTORS_DIR="./resources/connect-configs"
CONNECT_URL="http://localhost:8083/connectors"

for file in ${CONNECTORS_DIR}/*.json; do
    echo "Registering connector from file: $file"
    curl -X POST -H "Content-Type: application/json" --data @$file $CONNECT_URL
done

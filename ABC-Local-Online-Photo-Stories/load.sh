#!/usr/bin/bash

username=$1
password=$2
elasticsearch_url=$3

# Add the index mapping to Elasticsearch
curl -H 'Content-Type: application/json' -XPUT -u ${username}:${password} ${elasticsearch_url}/abc_local_online -d @elasticsearch/mapping.json

# Download the data, convert to ascii text
curl -s -l \
    https://data.gov.au/dataset/3fd356c6-0ad4-453e-82e9-03af582024c3/resource/d73f2a2a-c271-4edd-ac45-25fd7ad2241f/download/localphotostories20092014csv.csv \
    | cat -v | sed -e "s/^M$//" > /tmp/abclocalonline.csv

# Create the Logstash config
cat logstash/* > /tmp/logstash.conf

# Run Logstash
docker run --rm --dns 1.1.1.1 -it -e XPACK_MONITORING_ENABLED=false -v /tmp/abclocalonline.csv:/tmp/abclocalonline.csv -v /tmp/logstash.conf:/usr/share/logstash/pipeline/logstash.conf docker.elastic.co/logstash/logstash:6.2.3

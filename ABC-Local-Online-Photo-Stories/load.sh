#!/usr/bin/bash -x

scriptdir=$(readlink -f $0)
scriptdir=$(dirname ${scriptdir})

# Check for curl binary, die if we can't find it
if ! type -P curl >/dev/null; then
	echo "Could not find curl!"
	exit -1
fi

curl_args=""

# Check command-line arguments
USAGE="Ex. usage: $0 -h 'https://host:port' -u user -p password path/to/logs"
while getopts ":h:u:p:i" opt; do
    case $opt in
        h)
			es_endpoint=$OPTARG
            ;;
        u)
			es_username=$OPTARG
            ;;
        p)
			es_password=$OPTARG
			;;
		i)
			curl_args="--insecure ${curl_args}"
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			echo $USAGE
			exit -1
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			echo $USAGE
			exit -1
			;;
    esac
done

if [[ $es_username ]] && [[ $es_password ]]; then
	curl_args="-u ${es_username}:${es_password} ${curl_args}"
fi

# Check if we can actually connect to the specified Elasticsearch endpoint
if ! $(curl -XGET ${curl_args} -s $es_endpoint | grep tagline 1> /dev/null); then
	echo "$es_endpoint does not seem to be a valid Elasticsearch endpoint."
	exit -1
fi

# Generate output plugin template
echo -n "Creating Logstash output file..."
ls_output_conf=${scriptdir}/logstash/03-output.conf
cat > ${ls_output_conf}<<EOF
output {
  elasticsearch {
    hosts => [ "${es_endpoint}" ]
	manage_template => false
EOF
if [[ $es_username ]] && [[ $es_password ]]; then
  cat >> ${ls_output_conf}<<EOF
    user => "${es_username}"
    password => "${es_password}"
EOF
fi
cat >> ${ls_output_conf}<<EOF
    index => "abc_local_online"
  }
}
EOF
echo "done!"

# Add the index mapping to Elasticsearch
echo "Adding index mapping..."
curl -H 'Content-Type: application/json' -XPUT ${curl_args} ${es_endpoint}/abc_local_online -d @elasticsearch/mapping.json
echo 
echo "done!"

# Download the data, convert to ascii text
echo "Downloading data..."
curl -s -l \
    https://data.gov.au/dataset/3fd356c6-0ad4-453e-82e9-03af582024c3/resource/d73f2a2a-c271-4edd-ac45-25fd7ad2241f/download/localphotostories20092014csv.csv \
    | cat -v | sed -e "s/^M$//" > /tmp/abclocalonline.csv
echo "done!"

# Create the Logstash config
cat logstash/* > /tmp/logstash.conf

# Run Logstash
docker run --rm --dns 1.1.1.1 -it -e XPACK_MONITORING_ENABLED=false -v /tmp/abclocalonline.csv:/tmp/abclocalonline.csv -v /tmp/logstash.conf:/usr/share/logstash/pipeline/logstash.conf docker.elastic.co/logstash/logstash:6.2.3

#!/bin/bash

# $1 is the DNS domain name. Example: "tom.com"
# $2 is the DNS record name. Example: "www"
# $3 is the DNS record Type. Example: "AAAA"
# $4 is the DNS value

set -e


# If configured the http proxy and proxy isn't ready, it may cause error
export HTTP_PROXY=
export HTTPS_PROXY=


if ! which aliyun &> /dev/null; then
  echo "No found aliyun CLI. Installing it..."
  /bin/bash -c "$(curl -fsSL https://aliyuncli.alicdn.com/install.sh)"
fi

echo "Check aliyun DNS $1..."
dns_info=$(aliyun alidns DescribeDomainRecords --DomainName $1 --Type AAAA | jq ".DomainRecords.Record[] | select(.RR == \"$2\")")

if echo $dns_info | grep -q "$2"; then
  echo $dns_info
  record_id=$(echo $dns_info | jq -r '.RecordId')
  value=$(echo $dns_info | jq -r '.Value')
  echo "Found the record. RecordId is $record_id. Value is $value."
  if [ "$value" == "$4" ]; then
    echo "Record has right ip."
  else
    echo "Update record to ip $4."
    aliyun alidns UpdateDomainRecord --RR $2 --RecordId $record_id --Type $3 --Value $4
  fi
else
  echo "No such $3 record. Adding..."
  aliyun alidns AddDomainRecord --DomainName $1 --RR $2 --Type $3 --Value $4
fi



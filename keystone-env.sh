#!/bin/bash

if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
   echo "This script is designed to be sourced. Not executed. Settings will not permit unless sourced!"
   exit 1
fi


export OS_IDENTITY_API_VERSION=3
export OS_PROJECT_DOMAIN=Default
export OS_USER_DOMAIN_NAME=Default
export OS_CACERT=/opt/openstack-cli/env/ca-certificates.crt
export OS_REGION_NAME=RegionOne

echo "Duke OpenStack Environment will be used"

while :
do
   echo -n "Which endpoint would you like to use? (public, internal): "
   read endpoint
   if [ $endpoint == "internal" ]; then
      export OS_AUTH_URL=https://internal-auth-url:35357/v3
      export OS_INTERFACE=internal
      export OS_ENDPOINT_TYPE=internal
      break
   elif [ $endpoint == "public" ]; then
      export OS_AUTH_URL=https://public-auth-url:35357/v3
      export OS_INTERFACE=public
      export OS_ENDPOINT_TYPE=public
      break
   fi
done

echo -n "Please enter your OpenStack User Id: "
read OS_USERNAME
export OS_USERNAME

echo -n "Please enter your OpenStack Password: "
read -sr OS_PASSWORD
export OS_PASSWORD
echo ""

echo -n "Please enter your OpenStack Project: "
read OS_PROJECT
export OS_PROJECT
export OS_TENANT_NAME=${OS_PROJECT_NAME}
export OS_AUTH_URL=https://internal-auth-url:35357/v3

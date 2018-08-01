#!/bin/bash

# Copyright © 2018 AT&T Intellectual Property. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

CONFIGDIR="/opt/config"
IDIR=$(pwd)
SCRIPTDIR=$IDIR/scripts
STATUSFILE=$IDIR/status-log
ONAPPARAMETERSFILE=$SCRIPTDIR/onap-parameters.yaml


rm -f $STATUSFILE
touch $STATUSFILE

echo "Start deploying ONAP"
echo "127.0.0.1 onap" | tee -a /etc/hosts


# Set up Nexus for artifacts that are available in Akraino's repo
#VERSION=$(curl -s http://nexus3.att-akraino.org/repository/maven-public/org/akraino/onap/onap-amsterdam-vm/maven-metadata.xml | grep "<version>" | awk '{ split($1,a,">");split(a[2],b,"<"); print b[1]}')


# Disable HTTP repo method
#echo "" > $CONFIGDIR/onap_repo.txt


# Validate parameters
INGRESSCONTROLLERIP=$(cat $CONFIGDIR/ingress_controller_ip.txt)
echo ${INGRESSCONTROLLERIP%...} > $CONFIGDIR/ingress_controller_ip.txt

# Fix typos in proxy settings
sed -i 's/https:/http:/' $CONFIGDIR/http_proxy.txt
sed -i 's/http:/https:/' $CONFIGDIR/https_proxy.txt


# Setup HTTP proxy
HTTPPROXY=$(cat $CONFIGDIR/http_proxy.txt)
HTTPSPROXY=$(cat $CONFIGDIR/https_proxy.txt)
NOPROXY=$(cat $CONFIGDIR/no_proxy.txt)



if [[ ! -z $HTTPPROXY ]]; then 
  echo "Acquire::http::Proxy \"$HTTPPROXY\";" | tee -a /etc/apt/apt.conf
  echo "Acquire::http::Proxy \"$HTTPSPROXY\";" | tee -a /etc/apt/apt.conf
  defaultinterface=$(route | grep default | awk '{ print $8}')
  myip=$(ifconfig  $defaultinterface | grep 'inet addr' | awk '{ gsub("addr:",""); print $2} ')
  export http_proxy=$HTTPPROXY
  export https_proxy=$HTTPSPROXY
  export no_proxy=$myip,$NOPROXY
fi


# Generate onap_parameters.yaml
echo "NEXUS_HTTP_REPO: https://nexus.onap.org/content/sites/raw" | sudo tee $ONAPPARAMETERSFILE
echo "NEXUS_DOCKER_REPO: nexus3.onap.org:10001" | sudo tee -a $ONAPPARAMETERSFILE
echo "NEXUS_USERNAME: docker" | sudo tee -a $ONAPPARAMETERSFILE
echo "NEXUS_PASSWORD: docker" | sudo tee -a $ONAPPARAMETERSFILE

PUBLICNETID=$(cat $CONFIGDIR/public_net_id.txt)
echo "OPENSTACK_PUBLIC_NET_ID: $PUBLICNETID" | sudo tee -a $ONAPPARAMETERSFILE

PUBLICNETNAME=$(cat $CONFIGDIR/public_net_name.txt)
echo "OPENSTACK_PUBLIC_NET_NAME: $PUBLICNETNAME" | sudo tee -a $ONAPPARAMETERSFILE

OAMNETWORKCIDR=$(cat $CONFIGDIR/oam_net_cidr.txt)
echo "OPENSTACK_OAM_NETWORK_CIDR: $OAMNETWORKCIDR" | sudo tee -a $ONAPPARAMETERSFILE

OPENSTACKRCNAME=$(cat $CONFIGDIR/openstack_rc_name.txt)
echo "OPENSTACK_USERNAME: $OPENSTACKRCNAME" | sudo tee -a $ONAPPARAMETERSFILE

OPENSTACKRCPASSWORD=$(cat $CONFIGDIR/openstack_rc_password.txt)
echo "OPENSTACK_API_KEY: $OPENSTACKRCPASSWORD" | sudo tee -a $ONAPPARAMETERSFILE

OPENSTACKTENANTNAME=$(cat $CONFIGDIR/openstack_tenant_name.txt)
echo "OPENSTACK_TENANT_NAME: $OPENSTACKTENANTNAME" | sudo tee -a $ONAPPARAMETERSFILE

OPENSTACKTENANTID=$(cat $CONFIGDIR/openstack_tenant_id.txt)
echo "OPENSTACK_TENANT_ID: $OPENSTACKTENANTID" | sudo tee -a $ONAPPARAMETERSFILE

OPENSTACKREGION=$(cat $CONFIGDIR/openstack_region.txt)
echo "OPENSTACK_REGION: $OPENSTACKREGION" | sudo tee -a $ONAPPARAMETERSFILE

echo "OPENSTACK_API_VERSION: \"v3.0\"" | sudo tee -a $ONAPPARAMETERSFILE

KEYSTONEURL=$(cat $CONFIGDIR/keystone_url.txt)
echo "OPENSTACK_KEYSTONE_URL: $KEYSTONEURL" | sudo tee -a $ONAPPARAMETERSFILE

OPENSTACKSERVICETENANTNAME=$(cat $CONFIGDIR/openstack_service_tenant_name.txt)
echo "OPENSTACK_SERVICE_TENANT_NAME: $OPENSTACKSERVICETENANTNAME" | sudo tee -a $ONAPPARAMETERSFILE

SMALLFLAVORNAME=$(cat $CONFIGDIR/small_flavor_name.txt)
echo "OPENSTACK_FLAVOUR_SMALL: $SMALLFLAVORNAME" | sudo tee -a $ONAPPARAMETERSFILE

MEDIUMFLAVORNAME=$(cat $CONFIGDIR/medium_flavor_name.txt)
echo "OPENSTACK_FLAVOUR_MEDIUM: $MEDIUMFLAVORNAME" | sudo tee -a $ONAPPARAMETERSFILE

LARGEFLAVORNAME=$(cat $CONFIGDIR/large_flavor_name.txt)
echo "OPENSTACK_FLAVOUR_LARGE: $LARGEFLAVORNAME" | sudo tee -a $ONAPPARAMETERSFILE

UBUNTU1404IMAGE=$(cat $CONFIGDIR/ubuntu_1404_image.txt)
echo "OPENSTACK_UBUNTU_14_IMAGE: $UBUNTU1404IMAGE" | sudo tee -a $ONAPPARAMETERSFILE

UBUNTU1604IMAGE=$(cat $CONFIGDIR/ubuntu_1604_image.txt)
echo "OPENSTACK_UBUNTU_16_IMAGE: UBUNTU1604IMAGE" | sudo tee -a $ONAPPARAMETERSFILE

CENTOS7IMAGE=$(cat $CONFIGDIR/centos_image.txt)
echo "OPENSTACK_CENTOS_7_IMAGE: $CENTOS7IMAGE" | sudo tee -a $ONAPPARAMETERSFILE

DMMAPTOPICMODE=$(cat $CONFIGDIR/dmmap_topic_mode.txt)
echo "DMAAP_TOPIC: $DMMAPTOPICMODE" | sudo tee -a $ONAPPARAMETERSFILE

DEMOARTIFACTSVERSION=$(cat $CONFIGDIR/demo_artifacts_version.txt)
echo "DEMO_ARTIFACTS_VERSION: $DEMOARTIFACTSVERSION" | sudo tee -a $ONAPPARAMETERSFILE

echo "DEPLOY_DCAE: \"false\"" | sudo tee -a $ONAPPARAMETERSFILE


# Replace aai-cloud-region.json tenant ID
cd $SCRIPTDIR
TENANTID=$(cat $CONFIGDIR/openstack_tenant_id.txt)
sed -i 's/.*tenant-id.*/  '"                      \"tenant-id\": \"$TENANTID\",/" aai-cloud-region-put.json


chmod +x *.sh
./oom_kubeadm_setup.sh
./build-artifacts.sh
./prepull_docker.sh
./deploy_onap.sh


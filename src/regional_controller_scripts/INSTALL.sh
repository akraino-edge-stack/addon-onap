i#!/bin/bash

# Copyright © 2018-2019 AT&T Intellectual Property. All rights reserved.
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

#
#       INSTALL.sh - install ONAP add-on via Heat scripts, as well
#       as a few manual openstack commands.
#

IDIR=$(pwd)
BINDIR=./binaries
SCRIPTDIR=./scripts
KEYDIR=$IDIR/key
ADMIN_RC=$SCRIPTDIR/admin-openrc
ONAP_RC=$SCRIPTDIR/onap-openrc
HEAT1=$SCRIPTDIR//onap_baseline.yaml
HEAT2=$SCRIPTDIR//onap_install.yaml
ENVFILE=$SCRIPTDIR//onap.env
AAICLOUDREGIONFILE=$SCRIPTDIR/aai-cloud-region-put.json
STATUSCODE=$IDIR/status-code


echo $(date) Starting to install ONAP - OOM.
set -ex

echo "0" > $STATUSCODE

# Create onap.env enviroment file.
# Parameters in this enviroment file are used for onap_baseline HEAT template. Parameters required by onap_install template will be insert later during runtime
rm -f $ENVFILE

echo "parameters:" >> $ENVFILE
grep public_net_name $IDIR/parameters.env >> $ENVFILE
grep public_physical_net_provider_name $IDIR/parameters.env >> $ENVFILE
grep provider_segmentation_id $IDIR/parameters.env >> $ENVFILE
grep public_physical_net_type $IDIR/parameters.env >> $ENVFILE

grep public_subnet_name $IDIR/parameters.env >> $ENVFILE
grep public_subnet_cidr $IDIR/parameters.env >> $ENVFILE
grep public_subnet_allocation_start $IDIR/parameters.env >> $ENVFILE
grep public_subnet_allocation_end $IDIR/parameters.env >> $ENVFILE
grep public_subnet_dns_nameserver $IDIR/parameters.env >> $ENVFILE
grep public_subnet_gateway_ip $IDIR/parameters.env >> $ENVFILE

# Create ADMIN_RC file with correct password.
KEYSTONE_ADMIN_PASSWORD=$(grep keystone_admin_password $IDIR/parameters.env | awk '{print $2}')
cat >$ADMIN_RC <<EOF
export OS_AUTH_URL=http://keystone.openstack.svc.cluster.local:80/v3
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USERNAME=admin
export OS_PASSWORD=$KEYSTONE_ADMIN_PASSWORD
export OS_IMAGE_API_VERSION=2
export OS_IDENTITY_API_VERSION=3
EOF

# Create ONAP_RC file as well as enviroment file.
ONAP_TENANT_PASSWORD=$(grep onap_tenant_password $IDIR/parameters.env | awk '{print $2}')
cat >$ONAP_RC <<EOF
export OS_AUTH_URL=http://keystone.openstack.svc.cluster.local:80/v3
export OS_IDENTITY_API_VERSION=3
export OS_INSECURE=1
export OS_PASSWORD=$ONAP_TENANT_PASSWORD
export OS_PROJECT_DOMAIN_ID=default
export OS_PROJECT_NAME=onap
export OS_REGION_NAME=RegionOne
export OS_TENANT_NAME=onap
export OS_USER_DOMAIN_ID=default
export OS_USERNAME=onap
EOF
echo "  onap_password: $ONAP_TENANT_PASSWORD" >> $ENVFILE

# Run HEAT1 (onap_baseline) to create networks, subnets, flavors, etc.
echo set -ex
source $ADMIN_RC

PUBLIC_NETWORK_NAME=$(grep public_net_name $ENVFILE | awk '{print $2}')
DOES_PUBLIC_NETWORK_EXIST=$(openstack network list | grep $PUBLIC_NETWORK_NAME | awk '{print $2}')
if [ -n "$DOES_PUBLIC_NETWORK_EXIST" ]; then
    echo >> $ENVFILE
    echo "  does_public_net_exist: true" >> $ENVFILE
fi

PUBLIC_SUBNET_NAME=$(grep public_subnet_name $ENVFILE | awk '{print $2}')
DOES_SUBNET_EXIST=$(openstack subnet list | grep $PUBLIC_SUBNET_NAME | awk '{print $2}')
if [ -n "$DOES_SUBNET_EXIST" ]; then
        echo >> $ENVFILE
        echo "  does_public_subnet_exist: true" >> $ENVFILE
fi

openstack stack create -t $HEAT1 -e $ENVFILE onap_baseline --wait

LOOP=$(openstack stack list | grep onap_baseline | awk '{print $6}')
if [ $LOOP == "CREATE_FAILED" ]; then
    echo "Baseline creation failure."
    logger -s [0%] Baseline creation failure
    exit 1
fi

logger -s [0%] Loading VM images

# Run some manual commands which cannot be performed via Heat
rm -r -f $BINDIR
mkdir -p $BINDIR

openstack quota set --cores 80 --ram 300000 --instances 20 onap
UBUNTU16_04=$(openstack image list | grep ubuntu16_04 | awk '{print $2}')
if [ -z $UBUNTU16_04 ]; then
    curl -o $BINDIR/ubuntu-16.04-server-cloudimg-amd64-disk1.img https://cloud-images.ubuntu.com/releases/16.04/release/ubuntu-16.04-server-cloudimg-amd64-disk1.img
    openstack image create --file $BINDIR/ubuntu-16.04-server-cloudimg-amd64-disk1.img --disk-format qcow2 --container-format bare --public ubuntu16_04
fi

UBUNTU14_04=$(openstack image list | grep ubuntu14_04 | awk '{print $2}')
if [ -z \$UBUNTU14_04 ]; then
    curl -o $BINDIR/ubuntu-14.04-server-cloudimg-amd64-disk1.img https://cloud-images.ubuntu.com/releases/14.04/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img
    openstack image create --file $BINDIR/ubuntu-14.04-server-cloudimg-amd64-disk1.img --disk-format qcow2 --container-format bare --public ubuntu14_04
fi

source $ONAP_RC

# create onap.env enviroment file for ONAP VM.
# Parameters in this enviroment file are used for onap_install HEAT template.
rm -f $ENVFILE

echo "parameters:" >> $ENVFILE
echo "  onap_keypair_name: onap_key" >> $ENVFILE
echo "  oam_net_cidr: 10.48.0.1/24" >> $ENVFILE
echo "  ubuntu_1604_image: ubuntu16_04" >> $ENVFILE
echo "  ubuntu_1404_image: ubuntu14_04" >> $ENVFILE
echo "  centos_image: centos" >> $ENVFILE
echo "  openstack_rc_name: onap" >> $ENVFILE
echo "  openstack_rc_password: onap123" >> $ENVFILE
echo "  openstack_tenant_name: onap" >> $ENVFILE
echo "  openstack_region: RegionOne" >> $ENVFILE
echo "  keystone_url: http://keystone.openstack.svc.cluster.local" >> $ENVFILE
echo "  medium_flavor_name: m1.medium" >> $ENVFILE
echo "  small_flavor_name: m1.small" >> $ENVFILE
echo "  large_flavor_name: m1.large" >> $ENVFILE
echo "  openstack_service_tenant_name: service" >> $ENVFILE
echo "  dmmap_topic_mode: AUTO" >> $ENVFILE
echo "  demo_artifacts_version: 1.1.1-SNAPSHOT" >> $ENVFILE

grep onap_vm_public_key $IDIR/parameters.env >> $ENVFILE
grep flavor_name $IDIR/parameters.env >> $ENVFILE

http_proxy=$(grep http_proxy $IDIR/parameters.env | awk '{print $2}')
if [ -z $http_proxy ]; then
    echo "  http_proxy: \"\"" >> $ENVFILE
    echo "  no_proxy: \"\"" >> $ENVFILE
else
    grep http_proxy $IDIR/parameters.env >> $ENVFILE
    grep no_proxy $IDIR/parameters.env >> $ENVFILE
fi


https_proxy=$(grep https_proxy $IDIR/parameters.env | awk '{print $2}')
if [ -z $https_proxy ]; then
    echo "  https_proxy: \"\"" >> $ENVFILE
    echo "  no_proxy: \"\"" >> $ENVFILE
else
    grep https_proxy $IDIR/parameters.env >> $ENVFILE
    grep no_proxy $IDIR/parameters.env >> $ENVFILE
fi

onap_artifacts_http_repo=$(grep onap_artifacts_http_repo $IDIR/parameters.env | awk '{print $2}')
echo "  onap_repo: \"$onap_artifacts_http_repo\"" >> $ENVFILE

grep public_net_name $IDIR/parameters.env >> $ENVFILE
TENANTID=$(openstack project list | grep onap | awk '{ print $2 }')
echo "  openstack_tenant_id: $TENANTID" >> $ENVFILE

public_net_name=$(grep public_net_name $IDIR/parameters.env | awk '{print $2}')
PUBLICNETWORKID=$(openstack network list | awk "/ $public_net_name / {print \$2}")
echo "  public_net_id: $PUBLICNETWORKID" >> $ENVFILE

INGRESS_IP=$(kubectl get ep -n openstack | awk '/keystone / {split($2,a,":"); print a[1]};')
if [ -z $INGRESS_IP ]; then
    echo "Cannot locate the keystone api ingress controller."
    exit 1
fi
echo >>$ENVFILE
echo "  openstack_endpoint_ingress_controller: $INGRESS_IP" >> $ENVFILE


logger -s [0%] Creating ONAP VM


# Run HEAT2 (onap_install) to install ONAP proper
# Run as "onap" user
source $ONAP_RC
openstack stack create -t $HEAT2 -e $ENVFILE onap_install --wait

echo $(date) Done.
logger -s [0%] ONAP VM is running.
echo "1" > $STATUSCODE
exit 0


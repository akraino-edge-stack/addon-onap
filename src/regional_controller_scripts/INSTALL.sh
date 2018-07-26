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



#
#	INSTALL.sh - install ONAP add-on via Heat scripts, as well
#	as a few manual openstack commands.
#

IDIR=$(pwd)
BINDIR=$IDIR/binaries
SCRIPTDIR=$IDIR/scripts
KEYDIR=$IDIR/key
ADMIN_RC=$SCRIPTDIR/admin-openrc.sh
ADMIN_RC_TEMPLATE=$SCRIPTDIR/admin-openrc-template.sh
ONAP_RC=$SCRIPTDIR/onap-openrc.sh
ONAP_RC_TEMPLATE=$SCRIPTDIR/onap-openrc-template.sh
HEAT1=$SCRIPTDIR/onap_baseline.yaml
HEAT2=$SCRIPTDIR/onap_install.yaml
ENVFILE=$SCRIPTDIR/onap.env
AAICLOUDREGIONFILE=$SCRIPTDIR/aai-cloud-region-put.json
STATUSFILE=$IDIR/status-log


logger -s [0%] Creating Openstack project and networks for ONAP 2>> $STATUSFILE

# Need access to the os_run.sh tool
PATH=$SCRIPTDIR:$PATH

echo $(date) Starting to install ONAP - OOM.
set -ex

#
#	Check for keystone-api.  If not found, and keystone IS found, create the
#	keystone-api ingress endpoint.
#
PATH=$PATH:/usr/local/bin
if kubectl get ingress -n openstack keystone-api >/dev/null 2>&1
then
	echo keystone-api already defined.
else
	if kubectl get ingress -n openstack keystone -o yaml >/tmp/kc$$
	then
		egrep -v 'creationTimestamp:|resourceVersion:|selfLink:|uid:' < /tmp/kc$$ |
			sed 's/name: keystone/name: keystone-api/' |
			sed 's/host: keystone/host: keystone-api/' |
			sed 's/servicePort:.*/servicePort: 35357/' > /tmp/kc$$b
		kubectl apply -f - < /tmp/kc$$b
		rm -f /tmp/kc$$b
	fi
	rm -f /tmp/kc$$
fi





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




# Insert Keystone admin passphase to the ADMIN_RC file.
KEYSTONE_ADMIN_PASSWORD=$(grep keystone_admin_password $IDIR/parameters.env | awk '{print $2}')
rm -f $ADMIN_RC
cp $ADMIN_RC_TEMPLATE $ADMIN_RC
sed -i -e "s#--PASSPHASE-GOES-HERE--#$KEYSTONE_ADMIN_PASSWORD#g" $ADMIN_RC


# Insert Onap tenant passphase to the ONAP_RC file as well as enviroment file.
ONAP_TENANT_PASSWORD=$(grep onap_tenant_password $IDIR/parameters.env | awk '{print $2}')
rm -f $ONAP_RC
cp $ONAP_RC_TEMPLATE $ONAP_RC
sed -i -e "s#--PASSPHASE-GOES-HERE--#$ONAP_TENANT_PASSWORD#g" $ONAP_RC
echo "  onap_password: $ONAP_TENANT_PASSWORD" >> $ENVFILE






# Run HEAT1 (onap_baseline) to create networks, subnets, flavors, etc.
# Run as "admin" user
(
	echo set -ex
	cat $ADMIN_RC

        echo "PUBLIC_NETWORK_NAME=\$(grep public_net_name $ENVFILE | awk '{print \$2}')"
        echo "DOES_PUBLIC_NETWORK_EXIST=\$(openstack network list | grep \$PUBLIC_NETWORK_NAME | awk '{print \$2}')"
        echo "if [ -n \"\$DOES_PUBLIC_NETWORK_EXIST\" ]; then"
        echo "echo \$DOES_PUBLIC_NETWORK_EXIST"
        echo "echo >> $ENVFILE"
        echo "echo \"  does_public_net_exist: true\" >> $ENVFILE"
        echo fi

        echo "PUBLIC_SUBNET_NAME=\$(grep public_subnet_name $ENVFILE | awk '{print \$2}')"
        echo "DOES_SUBNET_EXIST=\$(openstack subnet list | grep \$PUBLIC_SUBNET_NAME | awk '{print \$2}')"
        echo "if [ -n \"\$DOES_SUBNET_EXIST\" ]; then"
        echo "echo >> $ENVFILE"
        echo "echo \"  does_public_subnet_exist: true\" >> $ENVFILE"
        echo fi

	echo openstack stack create -t $HEAT1 -e $ENVFILE onap_baseline
) > /tmp/INST$$a
os_run.sh -v $IDIR:$IDIR /tmp/INST$$a



# Wait until the ONAP_BASELINE is completed
(
        echo set -ex
        cat $ADMIN_RC
        echo "LOOP=\$(openstack stack list | grep onap_baseline | awk '{print \$6}')"
	echo "while [ \$LOOP == \"CREATE_IN_PROGRESS\" ]; do"
        echo "echo \"Waiting for onap_baseline to be created.\""
        echo "LOOP=\$(openstack stack list | grep onap_baseline | awk '{print \$6}')" 
        echo done
        echo "echo \$LOOP >> $SCRIPTDIR/temp"

) > /tmp/INST$$b
os_run.sh -v $IDIR:$IDIR /tmp/INST$$b

BASECREATESTATUS=$(cat $SCRIPTDIR/temp)

if [ $BASECREATESTATUS == "CREATE_FAILED" ]; then
echo "Baseline creation failure."
logger -s [0%] Baseline creation failure 2>> $STATUSFILE
exit 1
fi

rm -f $SCRIPTDIR/temp


logger -s [0%] Loading VM images 2>> $STATUSFILE


# Run some manual commands which cannot be performed via Heat
public_net_name=$(grep public_net_name $IDIR/parameters.env | awk '{print $2}')
rm -r -f $BINDIR
mkdir -p $BINDIR

(
	echo set -ex
	cat $ADMIN_RC
	echo openstack quota set --cores 80 --ram 300000 --instances 20 onap
        echo "UBUNTU16_04=\$(openstack image list | grep ubuntu16_04 | awk '{print \$2}')"
        echo "if [ -z \$UBUNTU16_04 ]; then"
        echo curl -o $BINDIR/ubuntu-16.04-server-cloudimg-amd64-disk1.img https://cloud-images.ubuntu.com/releases/16.04/release/ubuntu-16.04-server-cloudimg-amd64-disk1.img
	echo openstack image create --file $BINDIR/ubuntu-16.04-server-cloudimg-amd64-disk1.img --disk-format qcow2 --container-format bare --public ubuntu16_04
        echo fi
  
        echo "UBUNTU14_04=\$(openstack image list | grep ubuntu14_04 | awk '{print \$2}')"
        echo "if [ -z \$UBUNTU14_04 ]; then"
        echo curl -o $BINDIR/ubuntu-14.04-server-cloudimg-amd64-disk1.img https://cloud-images.ubuntu.com/releases/14.04/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img
	echo openstack image create --file $BINDIR/ubuntu-14.04-server-cloudimg-amd64-disk1.img --disk-format qcow2 --container-format bare --public ubuntu14_04
        echo fi


	cat $ONAP_RC
	

        echo "TENANTID=\$(openstack project list | grep onap | awk '{ print \$2 }')"
        echo "echo \"  openstack_tenant_id: \$TENANTID\" >> $SCRIPTDIR/temp"
#        echo "sed -i 's/.*openstack_tenant_id.*/  '\"openstack_tenant_id: \$TENANTID\"'/' $ENVFILE"

        echo "PUBLICNETWORKID=\$(openstack network list | awk 'NR>3{if(\$4==\"$public_net_name\"){print \$2}}')"
        echo "echo \"  public_net_id: \$PUBLICNETWORKID\" >> $SCRIPTDIR/temp"
#        echo "sed -i 's/.*public_net_id.*/  '\"public_net_id: \$PUBLICNETWORKID\"'/' $ENVFILE"
 
 
#        echo "PUBLICNETWORKNAME=\$(openstack network list | awk 'NR==4{ print \$4 }')"
#        echo "sed -i 's/.*public_net_name.*/  '\"public_net_name: \$PUBLICNETWORKNAME\"'/' $ENVFILE"	

) > /tmp/INST$$c
os_run.sh -v $IDIR:$IDIR /tmp/INST$$c





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
echo "  keystone_url: http://keystone-api.openstack.svc.cluster.local" >> $ENVFILE
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
cat $SCRIPTDIR/temp >> $ENVFILE
rm $SCRIPTDIR/temp
#awk 'FNR>2{print}' $IDIR/parameters.env >> $SCRIPTDIR/onap.env





# Find the ingress public IP for Keystone-api
#INGRESS_IP=$(kubectl get ing -n openstack | grep keystone-api | awk '{ print $3 }' )
#INGRESS_IP=${INGRESS_IP:0:-3}
#sed -i 's/.*openstack_endpoint_ingress_controller.*/  '"openstack_endpoint_ingress_controller: $INGRESS_IP/" $ENVFILE
INGRESS_IP=$(kubectl describe ing -n openstack keystone-api | grep Address | awk '{split($2,a,","); print a[1]}')
if [ -z $INGRESS_IP ]; then
echo "Cannot locate the keystone api ingress controller."
echo "Temp solution. May not work."
INGRESS_IP=$(ifconfig ingress0 | grep "inet addr" | awk '{split($2,a,":"); print a[2]}')
if [ -z $INGRESS_IP ]; then
INGRESS_IP=$(kubectl describe ing -n openstack openstack | grep ingress: | awk '{split($0,a,"("); split (a[2],b,":"); print b[1]}')
fi
fi
echo >>$ENVFILE
echo "  openstack_endpoint_ingress_controller: $INGRESS_IP" >> $ENVFILE


logger -s [0%] Creating ONAP VM 2>> $STATUSFILE


# Run HEAT2 (onap_install) to install ONAP proper
# Run as "onap" user
(
	echo set -ex
	cat $ONAP_RC
	echo openstack stack create -t $HEAT2 -e $ENVFILE onap_install
) > /tmp/INST$$d
os_run.sh -v $IDIR:$IDIR /tmp/INST$$d

# rm -f /tmp/INST$$[abc]
echo $(date) Done.
logger -s [0%] ONAP VM is running. 2>> $STATUSFILE
exit 0

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






IDIR=$(pwd)
CONSULPATCHDIR=$IDIR/../consul-patch
STATUSFILE=$IDIR/status-log

logger -s [0%] Deploying ONAP 2>> $STATUSFILE



echo "$(date)"
echo "provide onap-parameters.yaml and aai-cloud-region-put.json"

export KUBECONFIG=$KUBECONFIG:/root/.kube/config
export HELM_HOME=/root/.helm/






HTTPPROXY=$(cat /opt/config/http_proxy.txt)
HTTPSPROXY=$(cat /opt/config/https_proxy.txt)
NOPROXY=$(cat /opt/config/no_proxy.txt)
INGRESSCONTROLLERIP=$(cat /opt/config/ingress_controller_ip.txt)


if [[ ! -z $HTTPPROXY ]]; then

    #  Use OOM with proxy setting

    echo "Acquire::http::Proxy \"$HTTPPROXY\";" | tee -a /etc/apt/apt.conf
    echo "Acquire::http::Proxy \"$HTTPSPROXY\";" | tee -a /etc/apt/apt.conf

    defaultinterface=$(route | grep default | awk '{ print $8}')
    myip=$(ifconfig  $defaultinterface | grep 'inet addr' | awk '{ gsub("addr:",""); print $2} ')

    export http_proxy=$HTTPPROXY
    export https_proxy=$HTTPSPROXY
    export no_proxy=$myip,$NOPROXY

    proxyhost=$(echo $http_proxy | awk '{ split($1,a,"/"); split(a[3],b,":"); print b[1]}')
    proxyport=$(echo $http_proxy | awk '{ split($1,a,"/"); split(a[3],b,":"); print b[2]}')

    if [ -z $proxyport ];then
        proxyport=80
    fi

    mv ../oom_proxy ../oom
    find ../oom -type f -exec sed -i -e "s#--HTTP-PROXY-HOST-GOES-HERE--#$proxyhost#g" {} \;
    find ../oom -type f -exec sed -i -e "s#--HTTP-PROXY-PORT-GOES-HERE--#$proxyport#g" {} \;
    find ../oom -type f -exec sed -i -e "s#--HTTP-PROXY-GOES-HERE--#$HTTPPROXY#g" {} \;
    find ../oom -type f -exec sed -i -e "s#--HTTPS-PROXY-GOES-HERE--#$HTTPSPROXY#g" {} \;
    find ../oom -type f -exec sed -i -e "s#--NO-PROXY-GOES-HERE--#$NOPROXY#g" {} \;

else

    # Use OOM with no proxy setting

    mv ../oom_no_proxy ../oom

fi


# Use static IP to map OpenStack endpoints to the ingress controller IP
if [ -z $INGRESSCONTROLLERIP ]; then
echo "Please provide OpenStack endpoint ingress controller IP in onap-parameters.yaml."
exit 0
fi



sed -i '/ingressControllerIP/d' ../oom/kubernetes/mso/values.yaml

echo "ingressControllerIP: $INGRESSCONTROLLERIP" >> ../oom/kubernetes/mso/values.yaml




# Genereate corresponding aai-cloud-region-put-json to populate cloud site info to AAI
TENANTID=$(cat onap-parameters.yaml | grep OPENSTACK_TENANT_ID | awk '{ print $2 }')
TENANTNAME=$(cat onap-parameters.yaml | grep OPENSTACK_TENANT_NAME | awk '{ print $2 }')
sed -i 's/.*tenant-id.*/                        \"tenant-id\": '"$TENANTID,/" aai-cloud-region-put.json
sed -i 's/.*tenant-name.*/                        \"tenant-name\": '"$TENANTNAME/" aai-cloud-region-put.json

# fix virtual memory for onap-log:elasticsearch under Rancher 1.6.11 - OOM-431
sudo sysctl -w vm.max_map_count=262144

echo "start config pod"
# still need to source docker variables
source ../oom/kubernetes/oneclick/setenv.bash
#echo "source setenv override"
echo "moving onap-parameters.yaml to oom/kubernetes/config"
cp onap-parameters.yaml ../oom/kubernetes/config
cd ../oom/kubernetes/config
./createConfig.sh -n onap
cd ../../../scripts/

# usually the prepull takes up to 15 min - however hourly builds will finish the docker pulls before the config pod is finisheed
echo "verify onap-config is 0/1 not 1/1 - as in completed - an error pod - means you are missing onap-parameters.yaml or values are not set in it."
while [  $(kubectl get pods -n onap | grep config | grep 0/1 | grep Completed | wc -l) -eq 0 ]; do
    sleep 15
    echo "waiting for config pod to complete"
done




# The onap config pod fails to spesify the dmaap url for SDC. This is a temporary patch to fix this problem.
sed -i "s/.*ueb_url_list.*/            \"ueb_url_list\": \"dmaap.onap-message-router, dmaap.onap-message-router\",/" /dockerdata-nfs/onap/sdc/environments/AUTO.json
sed -i "s/.*fqdn.*/            \"fqdn\": [\"dmaap.onap-message-router\", \"dmaap.onap-message-router\"]/" /dockerdata-nfs/onap/sdc/environments/AUTO.json


# Consul fails using the latest image because key "script" is deprecated.
# This is a temporary patch
cp -r $CONSULPATCHDIR/* /dockerdata-nfs/onap/consul/consul-agent-config/


# we are not using this for now - to avoid fail fast helm issues during development testing helm 2.5+
#./createAll.bash -n onap
# workaround for OOM-448 - run independently

cd ../oom/kubernetes/oneclick
./createAll.bash -n onap -a aai
./createAll.bash -n onap -a consul
./createAll.bash -n onap -a msb
./createAll.bash -n onap -a mso
./createAll.bash -n onap -a message-router
./createAll.bash -n onap -a sdnc
./createAll.bash -n onap -a vid
./createAll.bash -n onap -a robot
./createAll.bash -n onap -a portal
./createAll.bash -n onap -a policy
./createAll.bash -n onap -a appc
./createAll.bash -n onap -a sdc
./createAll.bash -n onap -a dcaegen2
./createAll.bash -n onap -a log
./createAll.bash -n onap -a cli
./createAll.bash -n onap -a multicloud
./createAll.bash -n onap -a clamp
./createAll.bash -n onap -a vnfsdk
./createAll.bash -n onap -a uui
./createAll.bash -n onap -a aaf

#./createAll.bash -n onap -a vfc
#./createAll.bash -n onap -a kube2msb




printf "**** Deployment completed. Waiting for service pods to be ready. ****\n"
logger -s [0%] Completed ONAP deployment 2>> $STATUSFILE

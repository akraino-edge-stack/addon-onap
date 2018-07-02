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





echo "$(date)"
echo "Check if ONAP are functional"

echo "wait for all pods up for 15-22 min"
FAILED_PODS_LIMIT=0
MAX_WAIT_PERIODS=90 # 22 MIN
COUNTER=0
while [  $(kubectl get pods --all-namespaces | grep 0/ | wc -l) -gt $FAILED_PODS_LIMIT ]; do
    PENDING=$(kubectl get pods --all-namespaces | grep 0/ | wc -l)
    sleep 15
    LIST_PENDING=$(kubectl get pods --all-namespaces | grep 0/ )
    echo "${LIST_PENDING}"
    echo "${PENDING} pending > ${FAILED_PODS_LIMIT} at the ${COUNTER}th 15 sec interval"
    COUNTER=$((COUNTER + 1 ))
    MAX_WAIT_PERIODS=$((MAX_WAIT_PERIODS - 1))
    if [ "$MAX_WAIT_PERIODS" -eq 0 ]; then
      FAILED_PODS_LIMIT=120 
    fi
done

echo "report on non-running containers"
PENDING=$(kubectl get pods --all-namespaces | grep 0/)
PENDING_COUNT=$(kubectl get pods --all-namespaces | grep 0/ | wc -l)
PENDING_COUNT_AAI=$(kubectl get pods -n onap-aai | grep 0/ | wc -l)
if [ "$PENDING_COUNT_AAI" -gt 0 ]; then
    echo "down-aai=${PENDING_COUNT_AAI}"
fi
# todo don't stop if aai is down

PENDING_COUNT_APPC=$(kubectl get pods -n onap-appc | grep 0/ | wc -l)
if [ "$PENDING_COUNT_APPC" -gt 0 ]; then
    echo "down-appc=${PENDING_COUNT_APPC}"
fi
PENDING_COUNT_MR=$(kubectl get pods -n onap-message-router | grep 0/ | wc -l)
if [ "$PENDING_COUNT_MR" -gt 0 ]; then
    echo "down-mr=${PENDING_COUNT_MR}"
fi
PENDING_COUNT_SO=$(kubectl get pods -n onap-mso | grep 0/ | wc -l)
if [ "$PENDING_COUNT_SO" -gt 0 ]; then
    echo "down-so=${PENDING_COUNT_SO}"
fi
PENDING_COUNT_POLICY=$(kubectl get pods -n onap-policy | grep 0/ | wc -l)
if [ "$PENDING_COUNT_POLICY" -gt 0 ]; then
    echo "down-policy=${PENDING_COUNT_POLICY}"
fi
PENDING_COUNT_PORTAL=$(kubectl get pods -n onap-portal | grep 0/ | wc -l)
if [ "$PENDING_COUNT_PORTAL" -gt 0 ]; then
    echo "down-portal=${PENDING_COUNT_PORTAL}"
fi
PENDING_COUNT_LOG=$(kubectl get pods -n onap-log | grep 0/ | wc -l)
if [ "$PENDING_COUNT_LOG" -gt 0 ]; then
    echo "down-log=${PENDING_COUNT_LOG}"
fi
PENDING_COUNT_ROBOT=$(kubectl get pods -n onap-robot | grep 0/ | wc -l)
if [ "$PENDING_COUNT_ROBOT" -gt 0 ]; then
    echo "down-robot=${PENDING_COUNT_ROBOT}"
fi
PENDING_COUNT_SDC=$(kubectl get pods -n onap-sdc | grep 0/ | wc -l)
if [ "$PENDING_COUNT_SDC" -gt 0 ]; then
    echo "down-sdc=${PENDING_COUNT_SDC}"
fi
PENDING_COUNT_SDNC=$(kubectl get pods -n onap-sdnc | grep 0/ | wc -l)
if [ "$PENDING_COUNT_SDNC" -gt 0 ]; then
    echo "down-sdnc=${PENDING_COUNT_SDNC}"
fi
PENDING_COUNT_VID=$(kubectl get pods -n onap-vid | grep 0/ | wc -l)
if [ "$PENDING_COUNT_VID" -gt 0 ]; then
    echo "down-vid=${PENDING_COUNT_VID}"
fi

PENDING_COUNT_AAF=$(kubectl get pods -n onap-aaf | grep 0/ | wc -l)
if [ "$PENDING_COUNT_AAF" -gt 0 ]; then
    echo "down-aaf=${PENDING_COUNT_AAF}"
fi
PENDING_COUNT_CONSUL=$(kubectl get pods -n onap-consul | grep 0/ | wc -l)
if [ "$PENDING_COUNT_CONSUL" -gt 0 ]; then
    echo "down-consul=${PENDING_COUNT_CONSUL}"
fi
PENDING_COUNT_MSB=$(kubectl get pods -n onap-msb | grep 0/ | wc -l)
if [ "$PENDING_COUNT_MSB" -gt 0 ]; then
    echo "down-msb=${PENDING_COUNT_MSB}"
fi
PENDING_COUNT_DCAE=$(kubectl get pods -n onap-dcaegen2 | grep 0/ | wc -l)
if [ "$PENDING_COUNT_DCAE" -gt 0 ]; then
    echo "down-dcae=${PENDING_COUNT_DCAE}"
fi
PENDING_COUNT_CLI=$(kubectl get pods -n onap-cli | grep 0/ | wc -l)
if [ "$PENDING_COUNT_CLI" -gt 0 ]; then
    echo "down-cli=${PENDING_COUNT_CLI}"
fi
PENDING_COUNT_MULTICLOUD=$(kubectl get pods -n onap-multicloud | grep 0/ | wc -l)
if [ "$PENDING_COUNT_MULTICLOUD" -gt 0 ]; then
    echo "down-multicloud=${PENDING_COUNT_MULTICLOUD}"
fi
PENDING_COUNT_CLAMP=$(kubectl get pods -n onap-clamp | grep 0/ | wc -l)
if [ "$PENDING_COUNT_CLAMP" -gt 0 ]; then
    echo "down-clamp=${PENDING_COUNT_CLAMP}"
fi
PENDING_COUNT_VNFSDK=$(kubectl get pods -n onap-vnfsdk | grep 0/ | wc -l)
if [ "$PENDING_COUNT_VNFSDK" -gt 0 ]; then
    echo "down-vnfsdk=${PENDING_COUNT_VNFSDK}"
fi
PENDING_COUNT_UUI=$(kubectl get pods -n onap-uui | grep 0/ | wc -l)
if [ "$PENDING_COUNT_UUI" -gt 0 ]; then
    echo "down-uui=${PENDING_COUNT_UUI}"
fi
PENDING_COUNT_VFC=$(kubectl get pods -n onap-vfc | grep 0/ | wc -l)
if [ "$PENDING_COUNT_VFC" -gt 0 ]; then
    echo "down-vfc=${PENDING_COUNT_VFC}"
fi
PENDING_COUNT_KUBE2MSB=$(kubectl get pods -n onap-kube2msb | grep 0/ | wc -l)
if [ "$PENDING_COUNT_KUBE2MSB" -gt 0 ]; then
    echo "down-kube2msb=${PENDING_COUNT_KUBE2MSB}"
fi
echo "pending containers=${PENDING_COUNT}"
echo "${PENDING}"

echo "check filebeat 2/2 count for ELK stack logging consumption"
FILEBEAT=$(kubectl get pods --all-namespaces -a | grep 2/)
echo "${FILEBEAT}"
echo "sleep 4 min - to allow rest frameworks to finish"
sleep 240
echo "run healthcheck 3 times to warm caches and frameworks so rest endpoints report properly - see OOM-447"

#cd /dockerdata-nfs/onap/robot/
# OOM-484 - robot scripts moved
cd oom/kubernetes/robot
echo "run healthcheck prep 1"
./ete-k8s.sh health > ~/health1.out
echo "run healthcheck prep 2"
./ete-k8s.sh health > ~/health2.out
echo "run healthcheck for real - wait a further 6 min"
sleep 360
./ete-k8s.sh health 


echo "report results"
cd ../../../
echo "$(date)"
#set +a


printf "**** Done ****\n"


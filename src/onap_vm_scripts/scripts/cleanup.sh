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









echo "remove existing oom"
source ../oom/kubernetes/oneclick/setenv.bash
../oom/kubernetes/oneclick/deleteAll.bash -n onap
sleep 10
# verify
DELETED=$(kubectl get pods --all-namespaces -a | grep 0/ | wc -l)

helm delete --purge onap-config

sudo chmod -R 777 /dockerdata-nfs/onap
rm -rf /dockerdata-nfs/onap

#kubeadm reset


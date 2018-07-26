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
STATUSFILE=$IDIR/status-log

HTTPPROXY=$(cat /opt/config/http_proxy.txt)
HTTPSPROXY=$(cat /opt/config/https_proxy.txt)
NOPROXY=$(cat /opt/config/no_proxy.txt)



logger -s [0%] Deploying K8S cluster 2>> $STATUSFILE





if [[ ! -z $HTTPPROXY ]]; then
    echo "Acquire::http::Proxy \"$HTTPPROXY\";" | tee -a /etc/apt/apt.conf
    echo "Acquire::http::Proxy \"$HTTPSPROXY\";" | tee -a /etc/apt/apt.conf



    defaultinterface=$(route | grep default | awk '{ print $8}')
    myip=$(ifconfig  $defaultinterface | grep 'inet addr' | awk '{ gsub("addr:",""); print $2} ')

    export http_proxy=$HTTPPROXY
    export https_proxy=$HTTPSPROXY
    export no_proxy=$myip,$NOPROXY

fi


apt-get update && apt-get install -y apt-transport-https

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add

cat <<EOF > /etc/apt/sources.list.d/kubiernetes.list  
deb http://apt.kubernetes.io/ kubernetes-xenial main  
EOF

apt-get update


apt-get install -y docker.io

if [[ ! -z $HTTPPROXY ]]; then
# setup proxy for docker
    mkdir /etc/systemd/system/docker.service.d
    echo "[Service]
    Environment=\"HTTP_PROXY=$HTTPPROXY\"" | tee -a /etc/systemd/system/docker.service.d/http-proxy.conf
    systemctl daemon-reload
    systemctl restart docker

fi


apt-get install -y kubelet kubeadm kubectl kubernetes-cni





kubeadm init --service-cidr=10.96.0.0/12 --pod-network-cidr=192.168.0.0/16




#mkdir -p $HOME/.kube
#sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
#sudo chown $(id -u):$(id -g) $HOME/.kube/config

mkdir -p /root/.kube
sudo cp -f /etc/kubernetes/admin.conf /root/.kube/config
sudo chown $(id -u):$(id -g) /root/.kube/config

export KUBECONFIG=$KUBECONFIG:/root/.kube/config
export HELM_HOME=/root/.helm/


kubectl label nodes onap kubeadm.alpha.kubernetes.io/role=master

#Setup kubernetes network
#wget https://docs.projectcalico.org/v2.3/getting-started/kubernetes/installation/hosted/kubeadm/1.6/calico.yaml

#sed -i -e 's/10.96.232.136/10.96.0.136/g' calico.yaml


kubectl apply -f calico.yaml


#Enable master node run pod 
kubectl taint nodes --all node-role.kubernetes.io/master-



#wget http://storage.googleapis.com/kubernetes-helm/helm-v2.7.2-linux-amd64.tar.gz
wget http://storage.googleapis.com/kubernetes-helm/helm-v2.7.2-linux-amd64.tar.gz
tar -zxvf helm-v2.7.2-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm



kubectl create serviceaccount --namespace kube-system tiller

kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller

helm init --service-account tiller 


echo "Waiting for K8S cluster to be ready."
logger -s [0%] Waiting for K8S cluster to be ready 2>> $STATUSFILE

NUMLINE=$(kubectl get pods --all-namespaces | grep -c kube-system)
READINESS=$(kubectl get pods --all-namespaces | grep -c "0/")

while [ ! $NUMLINE -ge 11 ] || [ ! $READINESS -eq 0 ]; do
    
    kubectl get pods --all-namespaces

    echo ==================================
    echo $NUMLINE active pods, $READINESS are not ready.    
    sleep 5
    NUMLINE=$(kubectl get pods --all-namespaces | grep -c kube-system)
    READINESS=$(kubectl get pods --all-namespaces | grep -c "0/")

done

echo "K8S cluster is alive."
logger -s [0%] K8S cluster is alive.>> $STATUSFILE

#nohup ./deploy.sh 2>&1 &

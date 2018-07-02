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



# AT&T Edge Cloud ONAP

The AT&T Edge Cloud ONAP project contains software to deploy ONAP on AT&T Edge Cloud site.
It integrates the following technologies:
- Docker (Latest version from APT)
- Kuberadm (Latest version from APT)
- Calico Network v2.3
- Helm 2.7
- ONAP Operations Manager (1/20/2018 version, modified for AEC deployment)
- ONAP Amsterdam v1.1.1


# Deployment Strategy

ONAP Amsterdam (v1.1.1) is deployed on a tenant domain K8S cluster other than the AEC K8S cluster that is hosting OpenStack control plane. This tenant domain cluster is created using virtual machines(VMs) hosted on the infrastructure service compute hosts of the AEC OpenStack cluster. The current deployment plan deploys a single VM K8S cluster with no K8S component resilience. The future plan will extend this model to utilize multiple VMs to construct this ONAP K8S cluster in order to provide redundancy and geo-resiliency.


# Prerequisites


For the current deployment plan, you will need to have the following:
- **An Ubuntu 16.04 virtual machine that is resource rich**: A typical VM flavor that ONAP can run smoothly contains 28 vCPUs, 192GB ram, and 200 GB storage. Reducing resource will result in reduced responsiveness of ONAP services.
	
- **Access to public repositories**: During deployment time, ONAP components download artifacts from public repositories such as https://nexus3.onap.org. 

- **A HTTP server which can be accessed by the ONAP virtual machine**: This HTTP servers will be used to host all ONAP docker images as well as deployment scripts. The downloading speed directly determines how long does ONAP deployment take.
 
- **Access to AEC OpenStack service endpoints**: The AEC OpenStack service endpoints such as keystone-api and heat must be accessible from the ONAP VM.

- **Keystone API v2.0**: ONAP Amsterdam requires keystone v2.0 APIs. ONAP uses the internal keystone-api endpoint (e.g., port 35357). 

- **Exposure of port 30211**: The ONAP VNC portal is accessible from VM's port 30211. 







# Deployment automation through edgeboot

Automation of the ONAP deployment is done using edgeboot. At deployment time, edgeboot will create a VM and the corresponding OpenStack resources required by ONAP, configure ONAP deployment scripts, and trigger the deployment. A HTTP server is required to host all the required docker images as well as the automation scripts.


#### Upload ONAP docker images.

The ONAP docker images used by this deployment is available at http://mtmac5.research.att.com/edgeboot.$VERSION.onap.tar 
Please download, untar and upload the images to the HTTP server.
Example:
```
mkdir ./tmp
cd ./tmp
wget http://mtmac5.research.att.com/edgeboot.20180209.onap.tar
tar -xvf edgeboot.20180209.onap.tar
scp -i KEYFILE -r ./* USER@HTTP_SERVER_IP:/var/www/html/ 
```

#### Upload ONAP deployment scripts

The ONAP VM will download ONAP deployment scripts in this repository from the HTTP server.
Please download, tar the oom and scripts folders into a file called onap_oom_deploy_scripts.tar.gz, and upload the tar file to the HTTP server.
Example:
```
git clone ssh://git@codecloud.web.att.com:7999/st_aec/onap.git
tar -czvf onap_oom_deploy_scripts.tar.gz ./oom ./scripts
scp -i KEYFILE -r onap_oom_deploy_scripts.tar.gz USER@HTTP_SERVER_IP:/var/www/html/
```

#### Provide the HTTP server URL in the edgeboot configuration

It is important to make sure that edgeboot is configured with the correct HTTP server URL.
IMPORTANT: The URL string should end without "/". (This will be fixed in the next release.)



# Manual Deployment


## Pre-deployment
#### 1. Populate the following environment variables
- $http_proxy: http proxy URL (if proxy is required)
- $https_proxy: https proxy URL (if proxy is required)
- $no_proxy: list of domains and IPs that will bypass proxy (if proxy is required)
- $http_repo_url: URL of the HTTP server from which ONAP docker images will be download.
- $public_net_id: ID of the OpenStack public provider network
- $public_net_name: Name of the OpenStack public provider network
- $oam_net_cidr: CIDR of the OAM network
- $openstack_user_name: OpenStack user name
- $openstack_user_password: OpenStack user password
- $openstack_project_name: OpenStack project name
- $openstack_project_id: OpenStack project ID
- $openstack_region: OpenStack region
- $openstack_keystone_url: OpenStack keystone API endpoint URL. Only support v2.0 APIs.
- $openstack_service_tenant_name: OpenStack service tenant name
- $openstack_small_flavor_name: Name of the OpenStack small flavor
- $openstack_medium_flavor_name: Name of the OpenStack medium flavor
- $openstack_large_flavor_name: Name of the OpenStack large flavor
- $openstack_ubuntu_14_image: Name of the ubuntu 14.04 image
- $openstack_ubuntu_16_image: Name of the ubuntu 16.04 image
- $openstack_centos_7_image: Name of the CentOS7 image
- $dmmap_topic_mode: DMAAP topic mode
- $demo_artifacts_version: Demo program artifacts version
#### 2. Proxy Setting 

If the ONAP VM requires proxy to access the public repositories, please provide the proxy information. Please also includes the AEC specific domains into the no_proxy setting.
```
echo $http_proxy > /opt/config/http_proxy.txt
echo $https_proxy > /opt/config/https_proxy.txt
export no_proxy="localhost, .simpledemo.onap.org, .openstack.svc.cluster.local, .svc.cluster.local, $no_proxy"
echo $no_proxy > /opt/config/no_proxy.txt
```

#### 3. HTTP Server for ONAP docker images

Please provide the URL for the HTTP server from which the ONAP VM downloads the ONAP docker images.
```
echo $http_repo_url > /opt/config/onap_repo.txt
```

#### 4. Upload ONAP docker images

Please refer to the previous section.


## Deployment

In a VM that meets the above prerequisites, perform the following steps:
#### 1. Download the oom and scripts folders.
```
ONAP_REPO=$(cat /opt/config/onap_repo.txt)
cd /opt/config
wget $ONAP_REPO/onap_oom_deploy_scripts.tar.gz
tar -xvf onap_oom_deploy_scripts.tar.gz
cd ./scripts
chmod +x *.sh
```

#### 2. Populate required parameters in ./scripts/onap_parameters.yaml
```
echo "NEXUS_HTTP_REPO: https://nexus.onap.org/content/sites/raw" | sudo tee onap-parameters.yaml
echo "NEXUS_DOCKER_REPO: nexus3.onap.org:10001" | sudo tee -a onap-parameters.yaml
echo "NEXUS_USERNAME: docker" | sudo tee -a onap-parameters.yaml
echo "NEXUS_PASSWORD: docker" | sudo tee -a onap-parameters.yaml
echo "OPENSTACK_PUBLIC_NET_ID: \"$public_net_id\"" | sudo tee -a onap-parameters.yaml
echo "OPENSTACK_PUBLIC_NET_NAME: \"$public_net_name\"" | sudo tee -a onap-parameters.yaml
echo "OPENSTACK_OAM_NETWORK_CIDR: \"$oam_net_cidr\"" | sudo tee -a onap-parameters.yaml
echo "OPENSTACK_USERNAME: \"$openstack_user_name\"" | sudo tee -a onap-parameters.yaml
echo "OPENSTACK_API_KEY: \"$openstack_user_password\"" | sudo tee -a onap-parameters.yaml
echo "OPENSTACK_TENANT_NAME: \"$openstack_project_name\"" | sudo tee -a onap-parameters.yaml
echo "OPENSTACK_TENANT_ID: \"$openstack_project_id\"" | sudo tee -a onap-parameters.yaml
echo "OPENSTACK_REGION: \"$openstack_region\"" | sudo tee -a onap-parameters.yaml
echo "OPENSTACK_API_VERSION: \"v3.0\"" | sudo tee -a onap-parameters.yaml
echo "OPENSTACK_KEYSTONE_URL: \"$keystone_url\"" | sudo tee -a onap-parameters.yaml
echo "OPENSTACK_SERVICE_TENANT_NAME: \"$openstack_service_tenant_name\"" | sudo tee -a onap-parameters.yaml
echo "OPENSTACK_FLAVOUR_SMALL: \"$openstack_small_flavor_name\"" | sudo tee -a onap-parameters.yaml
echo "OPENSTACK_FLAVOUR_MEDIUM: \"$openstack_medium_flavor_name\"" | sudo tee -a onap-parameters.yaml
echo "OPENSTACK_FLAVOUR_LARGE: \"$openstack_large_flavor_name\"" | sudo tee -a onap-parameters.yaml
echo "OPENSTACK_UBUNTU_14_IMAGE: \"$openstack_ubuntu_14_image\"" | sudo tee -a onap-parameters.yaml
echo "OPENSTACK_UBUNTU_16_IMAGE: \"$openstack_ubuntu_16_image\"" | sudo tee -a onap-parameters.yaml
echo "OPENSTACK_CENTOS_7_IMAGE: \"$openstack_centos_7_image\"" | sudo tee -a onap-parameters.yaml
echo "DMAAP_TOPIC: \"$dmmap_topic_mode\"" | sudo tee -a onap-parameters.yaml
echo "DEMO_ARTIFACTS_VERSION: \"$demo_artifacts_version\"" | sudo tee -a onap-parameters.yaml
echo "DEPLOY_DCAE: \"false\"" | sudo tee -a onap-parameters.yaml
 ```
 
#### 3. Setup K8S cluster 
```
./oom_kubeadm_setup.sh
```

#### 4. Download and load ONAP docker images
```
./prepull_docker.sh
```

#### 5. Deploy ONAP
```
./deploy.sh
```


# ONAP Health Check
ONAP health check can be performed using the robot framework, which is running as a robot container after ONAP is deployed.
```
cd ./oom/kubernetes/robot
./ete-k8s.sh health
```

A functional ONAP deployment will have the following components passing the health check.
- SDNC
- A&AI
- Policy
- MSO
- SDC
- APPC
- Portal
- DMMAP
- VID
- MSB
- CLAMP


Currently DCAE is not deployed. MSO takes around 15 mintues to become alive.


# Release Notes
20180209 - Alpha version.




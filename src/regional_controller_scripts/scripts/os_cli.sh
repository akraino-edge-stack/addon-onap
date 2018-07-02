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
# os_run.sh - Run a script containing OpenStack commands inside a container that has
# access to those commands.
#

VDIR=
if [ "$1" == '-v' ]
then
	shift
	VDIR="-v $1"
	shift
fi


case "$1" in
/*)	SCRIPT=$1;;
*)	SCRIPT=`pwd`/$1;;
esac


IMAGE="kolla/ubuntu-source-horizon:4.0.0"

DNSIP=$( kubectl get svc/coredns -n kube-system -o jsonpath='{.spec.clusterIP}' )
TTYOPT=
tty -s && TTYOPT=-it

cat > /tmp/resolv$$ <<EOF
nameserver $DNSIP
search openstack.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
EOF

docker run $TTYOPT \
	-v /tmp/resolv$$:/etc/resolv.conf \
	$VDIR $IMAGE bash 

rm -f /tmp/resolv$$
exit 0

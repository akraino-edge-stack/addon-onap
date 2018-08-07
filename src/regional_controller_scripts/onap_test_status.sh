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
#       onap_test_status.sh - poll ONAP add-on deployment status info
#
IDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STATUSCODE=$IDIR/status-code

STATUS=$(cat $STATUSCODE)


PID=$(pgrep INSTALL.sh)



if [ -z $PID ];then

	if [ $STATUS -eq 1 ];then
		echo ONAP Deployment Complete
		exit 0
	else
		echo 1
		exit 0
	fi

fi

echo 0
exit 1




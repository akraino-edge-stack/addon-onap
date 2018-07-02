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


#function to provide help
#desc: this function provide help menu
#argument: -h for help, -p for path
#calling syntax: options






options() {
  cat <<EOF
Usage: $0 [PARAMs]
-h                  : help
-p (PATH)           : path for searching values.yaml
                      [in case no path is provided then is will scan current directories for values.yml]
EOF
}

#function to parse yaml file
#desc: this function convert yaml file to dotted notion
#argument: yaml file
#calling syntax: parse_yaml <yaml_file_name>

function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])(".")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

#algorithmic steps
#start
#scan all values.yaml files
#parse yaml file into dotted format
#for each lines check there is image tag in line
#store image name and check next line for version information
#if in next line version is not present as a subtag then call docker pull with imageName
#if version is present in next line then call docker pull with imageName and imageVersion
#end


#start processing for finding images and version

IDIR=$(pwd)
STATUSFILE=$IDIR/status-log

logger -s [0%] Scaning ONAP artifacts images 2>> $STATUSFILE




IMAGE_TEXT="image"
IMAGE_VERSION_TEXT="version\|image.tag"
LOCATION="../"
VALUES_FILE_NAME="values.yaml"




#scan for options menu
while getopts ":h:p:" PARAM; do
  case $PARAM in
    h)
      options
      exit 1
      ;;
    p)
      LOCATION=${OPTARG}
      ;;
    ?)
      options
      exit
      ;;
  esac
done


#docker login to nexus repo
docker login -u docker -p docker nexus3.onap.org:10001 > /dev/null 2>&1

HTTPREPO=$(cat /opt/config/onap_repo.txt)
if [[ "$HTTPREPO" == */ ]]
then
    HTTPREPO="${HTTPREPO::-1}"
fi

rm -f httpimagelist
rm -f dockerimagelist

touch httpimagelist
touch dockerimagelist


rm -fr progress
mkdir -p ./progress/pull
mkdir -p ./progress/download
mkdir -p ./progress/load



#scan all values.yaml files recursively
for filename in `find $LOCATION -name $VALUES_FILE_NAME`
do
        numberOfImages=0
	imagenameholder=""
        numberofimagekeywordfound=0
	#parse yaml files
        for line in  `parse_yaml $filename`
        do

#		if [[ $line == *"$IMAGE_VERSION_TEXT"* ]]; then
 		if echo $line | grep -q -i $IMAGE_VERSION_TEXT; then
                        if [[ -z  $imagenameholder  ]]; then
                        	echo "ERROR: find a version before I can find the image name."
			else
				version=$(echo $line | awk -F "=" '{print $2}'| sed -e 's/^"//' -e 's/"$//' )
				imagenameholder="$imagenameholder":"$version"
				numberOfImages=$((numberOfImages+1))
                                imagearray[$numberOfImages]=$imagenameholder

				imagenameholder=""
			fi
               
                else
			if echo $line | grep -q -i $IMAGE_TEXT; then
			#if [[ $line == *"$IMAGE_TEXT"* ]]; then
				if [[ !  -z  $imagenameholder  ]]; then

					numberOfImages=$((numberOfImages+1))
					imagearray[$numberOfImages]=$imagenameholder
					#docker pull $imagenameholder &
				fi

				imagenameholder=$(echo $line | awk -F "=" '{print $2}'| sed -e 's/^"//' -e 's/"$//' ) 
				numberofimagekeywordfound=$((numberofimagekeywordfound+1))	
			fi

		fi




        done

        if [[ !  -z  $imagenameholder  ]]; then

		numberOfImages=$((numberOfImages+1))
        	imagearray[$numberOfImages]=$imagenameholder
        fi


        

	if [ "$numberOfImages" -ne "$numberofimagekeywordfound" ]; then
		echo "Warnning: Number of images and number of pulls are not the same in chart $filename" 
		cat $filename
	fi




    for i in `seq $numberOfImages`; do

        DOCKERIMAGENAME=${imagearray[$i]}
        IMAGEFILENAME="${DOCKERIMAGENAME//\//_}.tar"
        HTTPREPOURL="$HTTPREPO/$IMAGEFILENAME"


        ISIMAGELOADED=$(docker images | awk '{ printf "%s:%s\n", $1, $2}' | grep $DOCKERIMAGENAME)

        if [[ -z $ISIMAGELOADED ]]; then
            ISIMAGEDOWNLOADSTARTED=$(cat httpimagelist | grep $IMAGEFILENAME)
	        if [[ -z $ISIMAGEDOWNLOADSTARTED ]]; then
                 echo New image $DOCKERIMAGENAME found.
		        if [[ `wget -S --spider $HTTPREPOURL  2>&1 | grep 'HTTP/1.1 200 OK'` ]]; then
                            echo Using HTTP repository for download
                            echo "$HTTPREPOURL $IMAGEFILENAME" >> httpimagelist
                        else
                            echo Start pulling ${imagearray[$i]} from docker repository.
                            if [ "${imagearray[$i]}" != "IfNotPresent" ]; then
                            	echo ${imagearray[$i]} >> dockerimagelist
                            fi
#                            ALTIMAGE=$(echo ${imagearray[$i]} | tr '/' '_')
#                            touch ./progress/pull/$ALTIMAGE && docker pull ${imagearray[$i]}; rm ./progress/pull/${imagearray[$i]} &
			fi
		    fi
	    fi 
        #echo Start pulling ${imagearray[$i]}
        #docker pull ${imagearray[$i]} &
	done

	#read -n 1 -s -r -p "Press any key to continue"

done



#wget $HTTPREPOURL && docker load -i $IMAGEFILENAME &


# complete processing
#MAX_WAIT_INTERVALS=300





logger -s [0%] Pulling ONAP artifacts 2>> $STATUSFILE



# Create Parallel Downloading Sessions. Limited to 5 sessions at each time



PARALLELSESSION_LIMIT=5

url_pointer=0

HTTPQUEUELENGTH=$(cat httpimagelist | wc -l)

ACTIVEHTTPSESSION=$(( HTTPQUEUELENGTH>PARALLELSESSION_LIMIT?PARALLELSESSION_LIMIT:HTTPQUEUELENGTH))
TARGETLINE=$ACTIVEHTTPSESSION

while [ $url_pointer -lt $TARGETLINE ];do
	((url_pointer=url_pointer+1))
	
	HTTPREPOURL=$(awk "NR==$url_pointer"' {print $1}' httpimagelist)
	IMAGEFILENAME=$(awk "NR==$url_pointer"' {print $2}' httpimagelist)
	
	echo "download" > ./progress/download/$IMAGEFILENAME && wget $HTTPREPOURL && rm ./progress/download/$IMAGEFILENAME &&  echo "load" > ./progress/load/$IMAGEFILENAME && docker load -i $IMAGEFILENAME && rm $IMAGEFILENAME && rm ./progress/load/$IMAGEFILENAME &
	
done

REMAININGQUEUELENGTH=$((HTTPQUEUELENGTH-TARGETLINE))
DOWNLOADSESSION=$(ls ./progress/download/ | wc -l)
LOADINGSESSION=$(ls ./progress/load/ | wc -l)
DOCKERSESSION=$(ls ./progress/pull/ | wc -l)
((TOTALSESSION=DOWNLOADSESSION+LOADINGSESSION+DOCKERSESSION+REMAININGQUEUELENGTH))



while [ $TOTALSESSION -gt 0 ]; do
  sleep 10
    

  DOWNLOADTOKEN=$((PARALLELSESSION_LIMIT-DOWNLOADSESSION))
  DOWNLOADTOKEN=$((REMAININGQUEUELENGTH>DOWNLOADTOKEN?DOWNLOADTOKEN:REMAININGQUEUELENGTH))
  
  
  if [ $DOWNLOADTOKEN -ne 0 ]; then
	  
	  TARGETLINE=$((url_pointer+DOWNLOADTOKEN))
	  while [ $url_pointer -lt $TARGETLINE ];do
	  	((url_pointer=url_pointer+1))
		HTTPREPOURL=$(awk "NR==$url_pointer"' {print $1}' httpimagelist)
		IMAGEFILENAME=$(awk "NR==$url_pointer"' {print $2}' httpimagelist)
	
		echo "download" > ./progress/download/$IMAGEFILENAME && wget $HTTPREPOURL && rm ./progress/download/$IMAGEFILENAME &&  echo "load" > ./progress/load/$IMAGEFILENAME && docker load -i $IMAGEFILENAME && rm $IMAGEFILENAME && rm ./progress/load/$IMAGEFILENAME &
	  done
	  
	  
  fi
  
  
  REMAININGQUEUELENGTH=$((HTTPQUEUELENGTH-TARGETLINE))
  DOWNLOADSESSION=$(ls ./progress/download/ | wc -l)
  LOADINGSESSION=$(ls ./progress/load/ | wc -l)
  DOCKERSESSION=$(ls ./progress/pull/ | wc -l)
  ((TOTALSESSION=DOWNLOADSESSION+LOADINGSESSION+DOCKERSESSION+REMAININGQUEUELENGTH))
  
  
  echo "Active HTTP session: $DOWNLOADSESSION; Queue Length: $REMAININGQUEUELENGTH; Docker load session: $LOADINGSESSION, Docker pull session: $DOCKERSESSION"
 

done










url_pointer=0

DOCKERQUEUELENGTH=$(cat dockerimagelist | wc -l)

ACTIVEHTTPSESSION=$(( DOCKERQUEUELENGTH>PARALLELSESSION_LIMIT?PARALLELSESSION_LIMIT:DOCKERQUEUELENGTH))
TARGETLINE=$ACTIVEHTTPSESSION




while [ $url_pointer -lt $TARGETLINE ];do
	((url_pointer=url_pointer+1))
	
	IMAGENAME=$(awk "NR==$url_pointer"' {print $1}' dockerimagelist)
	IMAGEPRINTNAME=$(echo $IMAGENAME | tr '/' '_')

	echo "pull" > ./progress/pull/$IMAGEPRINTNAME && docker pull $IMAGENAME; rm ./progress/pull/$IMAGEPRINTNAME &
	
done

REMAININGQUEUELENGTH=$((DOCKERQUEUELENGTH-TARGETLINE))
DOWNLOADSESSION=$(ls ./progress/download/ | wc -l)
LOADINGSESSION=$(ls ./progress/load/ | wc -l)
DOCKERSESSION=$(ls ./progress/pull/ | wc -l)
((TOTALSESSION=DOWNLOADSESSION+LOADINGSESSION+DOCKERSESSION+REMAININGQUEUELENGTH))



while [ $TOTALSESSION -gt 0 ]; do
  sleep 10
  
  DOWNLOADTOKEN=$((PARALLELSESSION_LIMIT-DOCKERSESSION))
  DOWNLOADTOKEN=$((REMAININGQUEUELENGTH>DOWNLOADTOKEN?DOWNLOADTOKEN:REMAININGQUEUELENGTH))
  
  
  if [ $DOWNLOADTOKEN -ne 0 ]; then
	  
	  TARGETLINE=$((url_pointer+DOWNLOADTOKEN))
	  while [ $url_pointer -lt $TARGETLINE ];do
	  	((url_pointer=url_pointer+1))

		 IMAGENAME=$(awk "NR==$url_pointer"' {print $1}' dockerimagelist)
	        IMAGEPRINTNAME=$(echo $IMAGENAME | tr '/' '_')

		echo "pull" > ./progress/pull/$IMAGEPRINTNAME && docker pull $IMAGENAME; rm ./progress/pull/$IMAGEPRINTNAME &
	  done
	  
	  
  fi
  
  
  REMAININGQUEUELENGTH=$((DOCKERQUEUELENGTH-TARGETLINE))
  DOWNLOADSESSION=$(ls ./progress/download/ | wc -l)
  LOADINGSESSION=$(ls ./progress/load/ | wc -l)
  DOCKERSESSION=$(ls ./progress/pull/ | wc -l)
  ((TOTALSESSION=DOWNLOADSESSION+LOADINGSESSION+DOCKERSESSION+REMAININGQUEUELENGTH))
  
  
  echo "Active HTTP session: $DOWNLOADSESSION; Queue Length: $REMAININGQUEUELENGTH; Docker load session: $LOADINGSESSION, Docker pull session: $DOCKERSESSION"
 
done

logger -s [0%] Completed pulling ONAP artifacts  2>> $STATUSFILE


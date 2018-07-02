from ubuntu:16.04

# Setup Corporate proxy

COPY ready.py /root/ready.py
RUN apt-get update; apt-get install -y apt-utils git wget curl dnsutils python python-pip jq net-tools coreutils vim; pip install requests pyyaml kubernetes; chmod a+x /root/ready.py

ENTRYPOINT /root/ready.py

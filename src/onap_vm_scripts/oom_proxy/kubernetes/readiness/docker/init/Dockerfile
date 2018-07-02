from ubuntu:16.04

# Setup Corporate proxy

COPY ready.py /root/ready.py
RUN export http_proxy=--HTTP-PROXY-GOES-HERE--; export https_proxy=--HTTPS-PROXY-GOES-HERE--; echo "Acquire::http::Proxy \"--HTTP-PROXY-GOES-HERE--\";" | tee -a /etc/apt/apt.conf; apt-get update; apt-get install -y apt-utils git wget curl dnsutils python python-pip jq net-tools coreutils vim; pip install requests pyyaml kubernetes; chmod a+x /root/ready.py

ENTRYPOINT /root/ready.py

#!/usr/bin/bash
set -ex

export DEBIAN_FRONTEND=noninteractive
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections


############################################################
# Install proxy
############################################################

# Use DPkg::Lock::Timeout=180 to avoid failing if an automatic update is in progress
apt-get update -y -o DPkg::Lock::Timeout=180
apt-get install -y -o DPkg::Lock::Timeout=180 \
  iptables-persistent \
  jq \
  netfilter-persistent \
  openssl \
  squid-openssl \
  curl


############################################################
# Setup routing and iptables
############################################################

INTERFACE=$(ip -j route show default | jq -r '.[0].dev')
if [ -z "$INTERFACE" ] || [ "$INTERFACE" = "null" ]; then
  echo "ERROR: Failed to find default network interface"
  exit 1
fi
echo "Using network interface: $INTERFACE"
ip addr show "$INTERFACE"

cat << 'SYSCTL' > /etc/sysctl.d/99-proxy.conf
net.ipv4.ip_forward = 1
SYSCTL
sysctl --system

# Flush any existing rules
iptables -F FORWARD
iptables -t nat -F
iptables -t mangle -F
ip6tables -F

# Block direct IPv4/IPv6 packet forwarding so non-80/443 traffic cannot bypass Squid via NAT
iptables -P FORWARD DROP
ip6tables -P FORWARD DROP
ip6tables -A FORWARD -i "$INTERFACE" -j REJECT

# Redirect HTTP and HTTPS traffic to local Squid intercept ports
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 3128
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 3129

# Masquerade outbound traffic leaving the proxy
iptables -t nat -A POSTROUTING -o "$INTERFACE" -j MASQUERADE

iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6
systemctl enable netfilter-persistent
systemctl restart netfilter-persistent


############################################################
# Configure Squid
############################################################

# Generate dummy SSL certificate required for Squid's transparent peeking framework
mkdir -p /etc/squid/ssl
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
  -subj "/C=UK/O=K8TRE/CN=transparent-proxy" \
  -keyout /etc/squid/ssl/dummy.pem -out /etc/squid/ssl/dummy.pem
chown -R proxy:proxy /etc/squid/ssl
chmod 400 /etc/squid/ssl/dummy.pem

# Initialize the SSL certificate database for the certgen helper
mkdir -p /var/lib/squid
rm -rf /var/lib/squid/ssl_db
/usr/lib/squid/security_file_certgen -c -s /var/lib/squid/ssl_db -M 4MB
chown -R proxy:proxy /var/lib/squid

# Ensure file exists before first GCS copy, must be non-empty
echo localhost > /etc/squid/allowlist.txt
chown proxy:proxy /etc/squid/allowlist.txt

# Overwrite default Squid configuration for transparent peek-and-splice
cat << 'SQUID' > /etc/squid/squid.conf
visible_hostname squid-proxy

######################################################################
# Access Control Lists

acl SSL_port port 443
acl step1 at_step SslBump1

acl allowed_domains dstdomain "/etc/squid/allowlist.txt"
acl allowed_domains_ssl ssl::server_name "/etc/squid/allowlist.txt"

# Avoid warning in the HTTP rule when HTTPS is blocked, since there's no response
acl hasResponse has response
acl http_blocked http_status 403
acl http_blocked_safe all-of hasResponse http_blocked

# HTTPS/TLS block rules (handshake terminated, no response returned)
acl ssl_blocked_hier hier_code HIER_NONE
acl ssl_blocked_status transaction_initiator client
acl ssl_blocked all-of CONNECT ssl_blocked_hier ssl_blocked_status !allowed_domains_ssl

# Combine them into a single "any_blocked" rule
acl any_blocked any-of http_blocked_safe ssl_blocked

######################################################################
# Logging

logformat transparent_sni %ts.%03tu %6tr %>a %Ss/%03>Hs %<st %rm %ru %ssl::>sni %Sh/%<A %mt
access_log daemon:/var/log/squid/access.log transparent_sni
access_log daemon:/var/log/squid/blocked.log transparent_sni any_blocked

######################################################################
# Filtering

http_port localhost:3130
http_port 3128 intercept
https_port 3129 intercept ssl-bump cert=/etc/squid/ssl/dummy.pem generate-host-certificates=on dynamic_cert_mem_cache_size=4MB

sslcrtd_program /usr/lib/squid/security_file_certgen -s /var/lib/squid/ssl_db -M 4MB

ssl_bump peek step1
ssl_bump splice allowed_domains_ssl
ssl_bump terminate all

cache deny all

http_access allow allowed_domains
http_access allow SSL_port
http_access deny all
SQUID

mkdir -p /etc/systemd/system/squid.service.d

cat << 'SYSTEMD_OVERRIDE' > /etc/systemd/system/squid.service.d/override.conf
[Service]
AmbientCapabilities=CAP_NET_BIND_SERVICE
ExecStartPre=/bin/sh -c 'gcloud storage cp gs://${gcs_config_bucket}/${name}-transparent-proxy/allowlist.txt /etc/squid/allowlist.txt || gsutil cp gs://${gcs_config_bucket}/${name}-transparent-proxy/allowlist.txt /etc/squid/allowlist.txt || true'
ExecStartPre=/bin/chown proxy:proxy /etc/squid/allowlist.txt
SYSTEMD_OVERRIDE

systemctl daemon-reload
systemctl restart squid
systemctl enable squid


############################################################
# Google Cloud Ops Agent
############################################################

curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install || true

cat << 'OPS_AGENT' > /etc/google-cloud-ops-agent/config.yaml
logging:
  receivers:
    squid_access:
      type: files
      include_paths: [/var/log/squid/access.log]
    squid_blocked:
      type: files
      include_paths: [/var/log/squid/blocked.log]
  service:
    pipelines:
      squid_pipeline:
        receivers: [squid_access, squid_blocked]
OPS_AGENT

systemctl restart google-cloud-ops-agent || true

echo "userdata completed!"

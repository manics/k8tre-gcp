# Transparent Squid outbound proxy (GCP)

Configures a transparent proxy on Google Compute Engine for restricting outbound HTTP and HTTPS traffic to a configurable list of domains.

## Requirements

When using an intercepting proxy with TLS peek-and-splice, client devices must NOT be configured to use an explicit HTTP/HTTPS proxy. Instead, standard HTTP (80) and HTTPS (443) traffic is routed to the proxy instance via a VPC route (`next_hop_instance`).

The proxy instance redirects traffic to Squid ports (3128 for HTTP, 3129 for HTTPS) and drops direct forwarding of non-HTTP/HTTPS traffic.

- For HTTP, Squid checks the destination hostname against `/etc/squid/allowlist.txt`.
- For HTTPS, Squid inspects the Server Name Indication (SNI) host in the TLS Client Hello handshake against `/etc/squid/allowlist.txt`.
- Access and blocked logs are shipped via Google Cloud Ops Agent to Cloud Logging (`squid_access` and `squid_blocked`), with a log-based metric and Cloud Monitoring alert policy on denied requests.

## Limitations

- When `allowed_domains` is updated, Squid is **not** automatically restarted; run `systemctl restart squid` on the instance by logging in via Identity-Aware Proxy (`gcloud compute ssh <instance-name> --tunnel-through-iap`).

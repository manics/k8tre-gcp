# Transparent Squid outbound proxy (GCP)

Configures a transparent proxy on Google Compute Engine for restricting outbound traffic to a configurable list of domains.

## Requirements

When using an intercepting proxy with TLS peek-and-splice, client devices must NOT be configured to use an explicit HTTP/HTTPS proxy. Instead, standard HTTP (80) and HTTPS (443) traffic must be routed to the proxy instance's internal IP.

The proxy instance will redirect traffic to Squid ports (3128 for HTTP, 3129 for HTTPS).

- For HTTP, Squid will check the destination hostname against `/etc/squid/allowlist.txt`.
- For HTTPS, Squid will inspect the Server Name Indication (SNI) host in the TLS Client Hello handshake against `/etc/squid/allowlist.txt`.

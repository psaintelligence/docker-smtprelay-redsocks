# docker-smtprelay-redsocks

Docker container that wraps [grafana/smtprelay](https://github.com/grafana/smtprelay) with redsocks.  

This has the effect of sending SMTP via your defined socks5 proxy.

## Usage
Refer to the grafana/smtprelay docs - https://github.com/grafana/smtprelay

## Redsocks Configuration
The following additional environment variables are available -

* REDSOCKS_TARGET_IP (default `socks-proxy`) - the target address outbound SMTP traffic is redirected to.  
* REDSOCKS_TARGET_PORT (default `1080`) - the target port.
* REDSOCKS_TARGET_TYPE (default `socks5`) - the target proxy type.  

## Sources

Container source -
* https://github.com/psaintelligence/docker-smtprelay-redsocks

Container repo -
* https://hub.docker.com/r/psaintelligence/smtprelay-redsocks

Source grafana/smtprelay -
* https://github.com/grafana/smtprelay

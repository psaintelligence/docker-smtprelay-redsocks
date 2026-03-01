# docker-smtprelay-redsocks

Docker container that wraps [grafana/smtprelay](https://github.com/grafana/smtprelay) with redsocks -

Container source -
* https://github.com/psaintelligence/docker-smtprelay-redsocks

Container repo -
* https://hub.docker.com/r/psaintelligence/smtprelay-redsocks

Source grafana/smtprelay -
* https://github.com/grafana/smtprelay

# Notes

The configuration in `/etc/redsocks.conf` is hardcoded to expect a socks5 proxy available 
at `socks-proxy:1080` that is typically deployed within a docker-compose arrangement.

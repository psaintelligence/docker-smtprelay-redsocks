
#
# https://stackoverflow.com/questions/70971310/how-to-make-docker-container-connect-everything-through-proxy
# https://github.com/grafana/smtprelay/blob/main/Dockerfile
#

# https://hub.docker.com/r/alpine/git/
# ===
FROM docker.io/alpine/git:latest AS source

# https://github.com/grafana/smtprelay/tags
#  v2.4.0 = 2026-01-29
ARG COMMIT_TAG=" v2.4.0"
ARG SOURCE_REPO="https://github.com/grafana/smtprelay.git"

WORKDIR /clone

RUN set -x && \
    export SOURCE_COMMIT_ID="$(echo ${COMMIT_TAG} | cut -d'+' -f2)" && \
    export SOURCE_TAG_BRANCH="$(echo ${COMMIT_TAG} | cut -d'+' -f1)" && \
    git clone --config advice.detachedHead=false --depth 1 --branch "${SOURCE_TAG_BRANCH}" "${SOURCE_REPO}" "/clone" && \
    git reset --hard "${SOURCE_COMMIT_ID}" && \
    git log


# ===
FROM docker.io/golang:1.25-trixie AS builder

RUN apt-get update && \
    apt-get install -y \
      ca-certificates \
      make \
      git

WORKDIR /go/src/github.com/grafana/smtprelay
COPY --from=source /clone/. ./

ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

ENV CGO_ENABLED=0
ENV GOOS=${TARGETOS} GOARCH=${TARGETARCH} GOARM=${TARGETVARIANT}

RUN go mod download -x
RUN make build
RUN bin/smtprelay --version


# ===
FROM docker.io/debian:trixie-slim AS production

RUN apt-get update && \
    apt-get install -y \
      iptables \
      iproute2 \
      iputils-ping \
      redsocks

RUN \
    echo '\n\
base {\n\
    log_debug = off;\n\
    log_info = on;\n\
    log = "file:/var/log/redsocks.log";\n\
    daemon = on;\n\
    user = redsocks;\n\
    group = redsocks;\n\
    redirector = iptables;\n\
}\n\
redsocks {\n\
    local_ip = 127.0.0.1;\n\
    local_port = 1080;\n\
    ip = socks-proxy;\n\
    port = 1080;\n\
    type = socks5;\n\
}\n'\
> /etc/redsocks.conf

RUN \
    echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo 'ping -c 1 -W 5 socks-proxy >/dev/null 2>&1 || { echo "ERROR: Host socks-proxy is unreachable" >&2; exit 1; }' >> /entrypoint.sh && \
    echo 'ip link add test_dummy type dummy 2>/dev/null && ip link delete test_dummy || { echo "ERROR: Container requires --cap-add=NET_ADMIN" >&2; exit 1; }' >> /entrypoint.sh && \
    echo 'iptables -t nat -A OUTPUT -p tcp --dport 25 -j REDIRECT --to-port 1080' >> /entrypoint.sh && \
    echo 'iptables -t nat -A OUTPUT -p tcp --dport 465 -j REDIRECT --to-port 1080' >> /entrypoint.sh && \
    echo 'iptables -t nat -A OUTPUT -p tcp --dport 587 -j REDIRECT --to-port 1080' >> /entrypoint.sh && \
    echo 'redsocks' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    chmod 755 /entrypoint.sh

USER 0
ENTRYPOINT ["/entrypoint.sh"]

# OCI Labels
LABEL org.opencontainers.image.title="Docker smtprelay with redsocks"
LABEL org.opencontainers.image.authors="Nicholas de Jong <ndejong@psaintelligence.ai>"
LABEL org.opencontainers.image.source="https://github.com/psaintelligence/docker-smtprelay-redsocks"


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
      gettext-base \
      redsocks && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /go/src/github.com/grafana/smtprelay/bin/smtprelay /usr/local/bin/smtprelay
COPY redsocks-template.conf /etc/redsocks-template.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

USER 0
ENTRYPOINT ["/entrypoint.sh"]

# OCI Labels
LABEL org.opencontainers.image.title="Docker smtprelay with redsocks"
LABEL org.opencontainers.image.authors="Nicholas de Jong <ndejong@psaintelligence.ai>"
LABEL org.opencontainers.image.source="https://github.com/psaintelligence/docker-smtprelay-redsocks"

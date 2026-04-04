#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

FROM alpine:3.23

ARG HS_VERSION=0.28.0
ARG TARGETARCH

WORKDIR /opt/src

RUN set -x \
    && apk add --no-cache bash bind-tools ca-certificates coreutils wget \
    && case "$TARGETARCH" in \
         amd64) HS_ARCH=amd64 ;; \
         arm64) HS_ARCH=arm64 ;; \
         *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
       esac \
    && HS_BIN="headscale_${HS_VERSION}_linux_${HS_ARCH}" \
    && HS_BASE_URL="https://github.com/juanfont/headscale/releases/download/v${HS_VERSION}" \
    && wget -q -O "/tmp/${HS_BIN}" "${HS_BASE_URL}/${HS_BIN}" \
    && wget -q -O /tmp/hs_checksums.txt "${HS_BASE_URL}/checksums.txt" \
    && cd /tmp \
    && grep " ${HS_BIN}$" hs_checksums.txt | sha256sum -c - \
    && mv "/tmp/${HS_BIN}" /usr/local/bin/headscale \
    && chmod 755 /usr/local/bin/headscale \
    && rm -f /tmp/hs_checksums.txt \
    && mkdir -p /etc/headscale /var/lib/headscale /var/run/headscale

COPY ./run.sh /opt/src/run.sh
COPY ./manage.sh /opt/src/manage.sh
COPY ./LICENSE.md /opt/src/LICENSE.md
RUN chmod 755 /opt/src/run.sh /opt/src/manage.sh \
    && ln -s /opt/src/manage.sh /usr/local/bin/hs_manage

EXPOSE 8080/tcp 9090/tcp
VOLUME ["/var/lib/headscale"]
CMD ["/opt/src/run.sh"]

ARG BUILD_DATE
ARG VERSION
ARG VCS_REF
ENV IMAGE_VER=$BUILD_DATE

LABEL maintainer="Lin Song <linsongui@gmail.com>" \
    org.opencontainers.image.created="$BUILD_DATE" \
    org.opencontainers.image.version="$VERSION" \
    org.opencontainers.image.revision="$VCS_REF" \
    org.opencontainers.image.authors="Lin Song <linsongui@gmail.com>" \
    org.opencontainers.image.title="Headscale Server on Docker" \
    org.opencontainers.image.description="Docker image to run a Headscale server, a self-hosted implementation of the Tailscale coordination server." \
    org.opencontainers.image.url="https://github.com/hwdsl2/docker-headscale" \
    org.opencontainers.image.source="https://github.com/hwdsl2/docker-headscale" \
    org.opencontainers.image.documentation="https://github.com/hwdsl2/docker-headscale"
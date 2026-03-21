FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y \
    git make gcc libssl-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/TelegramMessenger/MTProxy.git /tmp/MTProxy && \
    cd /tmp/MTProxy && \
    make && \
    cp objs/bin/mtproto-proxy /usr/local/bin/mtproto-proxy

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    curl ca-certificates libssl3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/bin/mtproto-proxy /usr/local/bin/mtproto-proxy

RUN mkdir -p /opt/amnezia /data
RUN printf '#!/bin/sh\ntail -f /dev/null\n' > /opt/amnezia/start.sh && \
    chmod a+x /opt/amnezia/start.sh

VOLUME /data
ENTRYPOINT ["/bin/sh", "/opt/amnezia/start.sh"]
CMD [""]


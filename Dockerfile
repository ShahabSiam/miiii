# ========================================================
# Stage: Builder (Debian-based)
# ========================================================
FROM golang:1.26-bookworm AS builder

WORKDIR /app
ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  gcc \
  curl \
  unzip \
  && rm -rf /var/lib/apt/lists/*

COPY . .

ENV CGO_ENABLED=1
ENV CGO_CFLAGS="-D_LARGEFILE64_SOURCE"

RUN go build -ldflags "-w -s" -o build/x-ui main.go
RUN chmod +x ./DockerInit.sh && ./DockerInit.sh "$TARGETARCH"


# ========================================================
# Stage: Final Image (Debian-based)
# ========================================================
FROM debian:bookworm-slim

ENV TZ=Asia/Tehran
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  tzdata \
  fail2ban \
  bash \
  curl \
  openssl \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/build/ /app/
COPY --from=builder /app/DockerEntrypoint.sh /app/
COPY --from=builder /app/x-ui.sh /usr/bin/x-ui

# Configure fail2ban
RUN rm -f /etc/fail2ban/jail.d/alpine-ssh.conf || true \
  && cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local \
  && sed -i "s/^\[ssh\]$/&\nenabled = false/" /etc/fail2ban/jail.local \
  && sed -i "s/^\[sshd\]$/&\nenabled = false/" /etc/fail2ban/jail.local \
  && sed -i "s/#allowipv6 = auto/allowipv6 = auto/g" /etc/fail2ban/fail2ban.conf

RUN chmod +x \
  /app/DockerEntrypoint.sh \
  /usr/bin/x-ui

ENV XUI_ENABLE_FAIL2BAN="true"

EXPOSE 2053

VOLUME [ "/etc/x-ui" ]

ENTRYPOINT [ "/app/DockerEntrypoint.sh" ]
CMD [ "/app/x-ui" ]

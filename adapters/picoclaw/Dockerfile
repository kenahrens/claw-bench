FROM golang:1.25-bookworm AS build

ARG PICOCLAW_REF=main

RUN apt-get update \
  && apt-get install -y --no-install-recommends git ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "${PICOCLAW_REF}" https://github.com/sipeed/picoclaw.git /src

WORKDIR /src

RUN go generate ./...

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
  -v \
  -tags "goolm stdjson" \
  -gcflags="all=-N -l" \
  -o /out/picoclaw \
  ./cmd/picoclaw

FROM debian:bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/* \
  && groupadd --gid 1000 picoclaw \
  && useradd --uid 1000 --gid 1000 --create-home --shell /bin/sh picoclaw \
  && mkdir -p /workspace /tmp \
  && chown -R 1000:1000 /workspace /tmp /home/picoclaw

COPY --from=build /out/picoclaw /usr/local/bin/picoclaw

USER 1000
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/picoclaw"]

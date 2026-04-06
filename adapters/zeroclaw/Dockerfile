FROM alpine:3.20

RUN addgroup -S app && adduser -S -G app app

# Replace this with the actual zero-claw binary copy step for your image source.
# Example:
# COPY --from=ghcr.io/vendor/zero-claw:latest /usr/local/bin/zero-claw /usr/local/bin/zero-claw

USER app
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/zero-claw"]

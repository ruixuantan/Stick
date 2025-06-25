FROM alpine:latest

RUN apk add zig
RUN apk add --update perf

WORKDIR /tmp/stick

COPY . .

ENTRYPOINT ["/bin/sh"]

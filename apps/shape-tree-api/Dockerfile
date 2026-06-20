FROM alpine:3.21

RUN apk add --no-cache git openssh-client

ARG BINARY_PATH=apps/shape-tree-api/.build/x86_64-swift-linux-musl/release/ShapeTree
COPY ${BINARY_PATH} /usr/local/bin/

RUN adduser -D -h /home/shape-tree shape-tree
USER shape-tree
WORKDIR /data
VOLUME /data

EXPOSE 42067
CMD ["ShapeTree"]

FROM alpine:3.21

RUN apk add --no-cache git openssh-client

ARG API_BINARY_PATH=apps/shape-tree-api/.build/aarch64-swift-linux-musl/release/ShapeTree
COPY ${API_BINARY_PATH} /usr/local/bin/

RUN adduser -D -h /home/shape-tree shape-tree
USER shape-tree
WORKDIR /data
VOLUME /data

EXPOSE 42067 42068
CMD ["ShapeTree"]

ARG TARGETARCH

FROM alpine:3.21 AS arch-amd64
COPY apps/shape-tree-api/.build/x86_64-swift-linux-musl/release/ShapeTree /ShapeTree

FROM alpine:3.21 AS arch-arm64
COPY apps/shape-tree-api/.build/aarch64-swift-linux-musl/release/ShapeTree /ShapeTree

FROM arch-${TARGETARCH} AS selected

FROM alpine:3.21
RUN apk add --no-cache git openssh-client

COPY --from=selected /ShapeTree /usr/local/bin/

RUN adduser -D -h /home/shape-tree shape-tree
USER shape-tree
WORKDIR /data
VOLUME /data

EXPOSE 42067 42068
CMD ["ShapeTree"]

FROM ubuntu AS build-env

ENV GOARCH=arm64
ENV GOOS=linux

RUN apt-get -yq update
RUN apt-get -yq install software-properties-common sudo
RUN apt-add-repository universe
RUN apt-add-repository multiverse
RUN apt-get -yq update
RUN apt-get -yq install gcc-aarch64-linux-gnu git make gcc bc device-tree-compiler u-boot-tools \
  ncurses-dev qemu-user-static wget cpio kmod squashfs-tools bison flex libssl-dev patch \
  xz-utils b43-fwcutter bzip2 ccache gawk golang
RUN apt-get -yq clean
RUN go get -d github.com/kubernetes-csi/driver-registrar || true
RUN cd /root/go/src/github.com/kubernetes-csi/driver-registrar && \
    REV=$(git describe --long --match='v*' --dirty) && \
    mkdir -p bin && \
    CGO_ENABLED=0 go build -a -ldflags "-X main.version=v0.2.0-9-$REV -extldflags '-static'" -o ./bin/driver-registrar ./cmd/driver-registrar
RUN cd / && \
    wget https://github.com/multiarch/qemu-user-static/releases/download/v2.12.0/x86_64_qemu-aarch64-static.tar.gz && \
    tar zxvf x86_64_qemu-aarch64-static.tar.gz

FROM arm64v8/alpine:3.7
LABEL description="CSI Driver registrar"

COPY --from=build-env /root/go/src/github.com/kubernetes-csi/driver-registrar/bin/driver-registrar driver-registrar
COPY --from=build-env /qemu-aarch64-static /usr/bin/qemu-aarch64-static
RUN mkdir -p /registration
ENTRYPOINT ["/driver-registrar"]


###################################
#Build stage
FROM golang:alpine3.11 AS build-env

ARG GOPROXY
ENV GOPROXY ${GOPROXY:-direct}

ARG GITEA_VERSION="v1.12.1"
ARG TAGS="sqlite sqlite_unlock_notify"
ENV TAGS "bindata $TAGS"

#Build deps
RUN apk --no-cache add build-base git nodejs npm upx

#Setup repo
#COPY . ${GOPATH}/src/code.gitea.io/gitea
RUN git clone https://github.com/go-gitea/gitea.git ${GOPATH}/src/code.gitea.io/gitea
WORKDIR ${GOPATH}/src/code.gitea.io/gitea

#Checkout version if set
RUN if [ -n "${GITEA_VERSION}" ]; then git checkout "${GITEA_VERSION}"; fi \
 && make clean build \
 && upx --best gitea

FROM alpine
LABEL maintainer="maintainers@gitea.io"
LABEL maintainer="mq83"

EXPOSE 22 3000

RUN apk --no-cache add \
    bash \
    ca-certificates \
    curl \
    gettext \
    git \
    linux-pam \
    openssh \
    s6 \
    sqlite \
    su-exec \
    tzdata

RUN addgroup \
    -S -g 1000 \
    git && \
  adduser \
    -S -H -D \
    -h /data/git \
    -s /bin/bash \
    -u 1000 \
    -G git \
    git && \
  echo "git:$(dd if=/dev/urandom bs=24 count=1 status=none | base64)" | chpasswd

ENV USER git
ENV GITEA_CUSTOM /data/gitea

VOLUME ["/data"]

ENTRYPOINT ["/usr/bin/entrypoint"]
CMD ["/bin/s6-svscan", "/etc/s6"]

COPY --from=build-env /go/src/code.gitea.io/gitea/docker/root /
COPY --from=build-env /go/src/code.gitea.io/gitea/gitea /app/gitea/gitea
RUN ln -s /app/gitea/gitea /usr/local/bin/gitea

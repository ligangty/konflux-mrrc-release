FROM registry.access.redhat.com/ubi8/go-toolset:latest


LABEL description="Konflux MRRC release image" \
      summary="Konflux MRRC release image" \
      maintainer="Gang Li" \
      vendor="Red Hat, Inc." \
      distribution-scope="public" 

ARG USER=mrrc
ARG UID=10000
ARG HOME_DIR=/home/${USER}

WORKDIR ${HOME_DIR}

USER root

RUN dnf install -y git-core gcc \
    && dnf clean all
RUN useradd -d ${HOME_DIR} -u ${UID} -g 0 -m -s /bin/bash ${USER} \
    && chown ${USER}:0 ${HOME_DIR} \
    && chmod -R g+rwx ${HOME_DIR} \
    && chmod g+rw /etc/passwd

COPY ./go.mod ./main.go ./

RUN go build -o main .

USER ${USER}

ENV HOME=${HOME_DIR} \
    LANG=en_US.UTF-8

ENTRYPOINT ["./main"]
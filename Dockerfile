# (first line comment needed for DOCKER_BUILDKIT use)
#
# cilium-envoy from github.com/cilium/proxy
#
FROM quay.io/cilium/cilium-envoy:1177896bebde79915fe5f9092409bf0254084b4e@sha256:50fb77af2b3fa8a902bb11b26c97c2c230fba74bdb417a645bd938278a6f81df as cilium-envoy
ARG CILIUM_SHA=""
LABEL cilium-sha=${CILIUM_SHA}

#
# Hubble CLI
#
FROM quay.io/cilium/hubble:v0.7.1@sha256:cc76aa6394d613eaeeac0f15b72f50d426b3c47d4676557431661e6aa5e1597b as hubble
ARG CILIUM_SHA=""
LABEL cilium-sha=${CILIUM_SHA}

#
# Cilium incremental build. Should be fast given builder-deps is up-to-date!
#
# cilium-builder tag is the date on which the compatible build image
# was pushed.  If a new version of the build image is needed, it needs
# to be tagged with a new date and this file must be changed
# accordingly.  Keeping the old images available will allow older
# versions to be built while allowing the new versions to make changes
# that are not backwards compatible.
#
FROM quay.io/cilium/cilium-builder:2021-02-15-v1.9@sha256:88daa4fd4f427bf7fe8fcf3a544e1c2c4407e06a72571121ec8135e2e1f4aa5b as builder
ARG CILIUM_SHA=""
LABEL cilium-sha=${CILIUM_SHA}
LABEL maintainer="maintainer@cilium.io"
WORKDIR /go/src/github.com/cilium/cilium
COPY . ./
ARG NOSTRIP
ARG LOCKDEBUG
ARG RACE
ARG V
ARG LIBNETWORK_PLUGIN
#
# Please do not add any dependency updates before the 'make install' here,
# as that will mess with caching for incremental builds!
#
RUN make RACE=$RACE NOSTRIP=$NOSTRIP LOCKDEBUG=$LOCKDEBUG PKG_BUILD=1 V=$V LIBNETWORK_PLUGIN=$LIBNETWORK_PLUGIN \
    SKIP_DOCS=true DESTDIR=/tmp/install build-container install-container \
    licenses-all

#
# Cilium runtime install.
#
# cilium-runtime tag is a date on which the compatible runtime base
# was pushed.  If a new version of the runtime is needed, it needs to
# be tagged with a new date and this file must be changed accordingly.
# Keeping the old runtimes available will allow older versions to be
# built while allowing the new versions to make changes that are not
# backwards compatible.
#
FROM quay.io/cilium/cilium-runtime:2021-02-15-v1.9@sha256:26c3617d57d459bf4583f8e2099932f0f6a23b2a0b9f5d9b428d147b6ad14c40
ARG CILIUM_SHA=""
LABEL cilium-sha=${CILIUM_SHA}
LABEL maintainer="maintainer@cilium.io"
COPY --from=builder /tmp/install /
COPY --from=cilium-envoy / /
COPY --from=hubble /usr/bin/hubble /usr/bin/hubble
COPY --from=builder /go/src/github.com/cilium/cilium/plugins/cilium-cni/cni-install.sh /cni-install.sh
COPY --from=builder /go/src/github.com/cilium/cilium/plugins/cilium-cni/cni-uninstall.sh /cni-uninstall.sh
COPY --from=builder /go/src/github.com/cilium/cilium/contrib/packaging/docker/init-container.sh /init-container.sh
COPY --from=builder /go/src/github.com/cilium/cilium/LICENSE.all /LICENSE.all
WORKDIR /home/cilium
RUN groupadd -f cilium \
    && /usr/bin/hubble completion bash > /etc/bash_completion.d/hubble \
    && echo ". /etc/profile.d/bash_completion.sh" >> /etc/bash.bashrc

ENV INITSYSTEM="SYSTEMD"
# FIXME Remove me once we add support for Go 1.16
ENV GODEBUG="madvdontneed=1"
CMD ["/usr/bin/cilium"]
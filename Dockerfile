FROM alpine:3.6

# The official Prometheus base image has no package manager so rather than
# artisanally hand-rolling curl and the rest of our stack we'll just use
# Alpine so we can use `docker build`.

RUN apk add --update curl bash

# add Prometheus. alas, the Prometheus developers provide no checksum
RUN export PROM_VERSION=1.7.2 \
    && export PROM_CHECKSUM=a5d56b613b77e1d12e99ed5f77359d097c63cb6db64e8b04496eff186df11484 \
    && export prom=prometheus-${PROM_VERSION}.linux-amd64 \
    && curl -Lso /tmp/${prom}.tar.gz https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/${prom}.tar.gz \
    && echo "${PROM_CHECKSUM}  /tmp/${prom}.tar.gz" | sha256sum -c \
    && tar zxf /tmp/${prom}.tar.gz -C /tmp \
    && mkdir /etc/prometheus /usr/share/prometheus \
    && mv /tmp/${prom}/prometheus /bin/prometheus \
    && mv /tmp/${prom}/promtool /bin/promtool \
    && mv /tmp/${prom}/prometheus.yml /etc/prometheus/ \
    && mv /tmp/${prom}/consoles /usr/share/prometheus/consoles \
    && mv /tmp/${prom}/console_libraries /usr/share/prometheus/console_libraries \
    && ln -s /usr/share/prometheus/console_libraries /usr/share/prometheus/consoles/ /etc/prometheus/ \
    && rm /tmp/prometheus-${PROM_VERSION}.linux-amd64.tar.gz

# Install Consul
# Releases at https://releases.hashicorp.com/consul
# Add consul agent
RUN export CONSUL_VERSION=1.0.1 \
    && export CONSUL_CHECKSUM=eac5755a1d19e4b93f6ce30caaf7b3bd8add4557b143890b1c07f5614a667a68 \
    && curl --retry 7 --fail -vo /tmp/consul.zip "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip" \
    && echo "${CONSUL_CHECKSUM}  /tmp/consul.zip" | sha256sum -c \
    && unzip /tmp/consul -d /usr/local/bin \
    && rm /tmp/consul.zip \
    && mkdir -p /etc/consul \
    && mkdir -p /var/lib/consul \
    && mkdir /config

# Install Consul template
# Releases at https://releases.hashicorp.com/consul-template/
RUN set -ex \
    && export CONSUL_TEMPLATE_VERSION=0.18.0 \
    && export CONSUL_TEMPLATE_CHECKSUM=f7adf1f879389e7f4e881d63ef3b84bce5bc6e073eb7a64940785d32c997bc4b \
    && curl --retry 7 --fail -Lso /tmp/consul-template.zip "https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip" \
    && echo "${CONSUL_TEMPLATE_CHECKSUM}  /tmp/consul-template.zip" | sha256sum -c \
    && unzip /tmp/consul-template.zip -d /usr/local/bin \
    && rm /tmp/consul-template.zip

# Add ContainerPilot and set its configuration file path
ENV CONTAINERPILOT_VER 3.5.1
ENV CONTAINERPILOT /etc/containerpilot.json
RUN export CONTAINERPILOT_CHECKSUM=7ee8e59588b6b593325930b0dc18d01f666031d7 \
    && curl -Lso /tmp/containerpilot.tar.gz \
    "https://github.com/joyent/containerpilot/releases/download/${CONTAINERPILOT_VER}/containerpilot-${CONTAINERPILOT_VER}.tar.gz" \
    && echo "${CONTAINERPILOT_CHECKSUM}  /tmp/containerpilot.tar.gz" | sha1sum -c \
    && tar zxf /tmp/containerpilot.tar.gz -C /usr/local/bin \
    && rm /tmp/containerpilot.tar.gz

COPY node_exporter/node_exporter /usr/local/bin/node_exporter

# Add Containerpilot configuration
COPY etc/containerpilot.json /etc

# Add Prometheus config template
# ref https://prometheus.io/docs/operating/configuration/
# for details on building your own config
COPY etc/prometheus.yml.ctmpl /etc/prometheus/prometheus.yml.ctmpl
COPY bin /bin

WORKDIR /prometheus
ENTRYPOINT []
CMD ["/usr/local/bin/containerpilot"]

HEALTHCHECK --interval=1m30s --timeout=10s --retries=3 CMD curl -f http://localhost:9090/graph || exit 1

LABEL org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.license="MPL-2.0" \
    org.label-schema.vendor="https://bitbucket.org/double16" \
    org.label-schema.name="Autopilot Prometheus Server" \
    org.label-schema.url="https://github.com/double16/autopilotpattern-prometheus" \
    org.label-schema.docker.dockerfile="Dockerfile" \
    org.label-schema.vcs-ref=$SOURCE_REF \
    org.label-schema.vcs-type='git' \
    org.label-schema.vcs-url="https://github.com/double16/autopilotpattern-prometheus.git"

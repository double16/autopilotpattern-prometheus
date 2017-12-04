FROM alpine:3.6

# The official Promtheus base image has no package manager so rather than
# artisanally hand-rolling curl and the rest of our stack we'll just use
# Alpine so we can use `docker build`.

RUN apk add --update curl

# add Prometheus. alas, the Prometheus developers provide no checksum
RUN export prom=prometheus-1.3.0.linux-amd64 \
    && curl -Lso /tmp/${prom}.tar.gz https://github.com/prometheus/prometheus/releases/download/v1.3.0/${prom}.tar.gz \
    && tar zxf /tmp/${prom}.tar.gz -C /tmp \
    && mkdir /etc/prometheus /usr/share/prometheus \
    && mv /tmp/${prom}/prometheus /bin/prometheus \
    && mv /tmp/${prom}/promtool /bin/promtool \
    && mv /tmp/${prom}/prometheus.yml /etc/prometheus/ \
    && mv /tmp/${prom}/consoles /usr/share/prometheus/consoles \
    && mv /tmp/${prom}/console_libraries /usr/share/prometheus/console_libraries \
    && ln -s /usr/share/prometheus/console_libraries /usr/share/prometheus/consoles/ /etc/prometheus/ \
    && rm /tmp/prometheus-1.3.0.linux-amd64.tar.gz

# get consul-template
RUN curl -Lso /tmp/consul-template_0.14.0_linux_amd64.zip https://releases.hashicorp.com/consul-template/0.14.0/consul-template_0.14.0_linux_amd64.zip \
    && echo "7c70ea5f230a70c809333e75fdcff2f6f1e838f29cfb872e1420a63cdf7f3a78" /tmp/consul-template_0.14.0_linux_amd64.zip \
    && unzip /tmp/consul-template_0.14.0_linux_amd64.zip \
    && mv consul-template /bin \
    && rm /tmp/consul-template_0.14.0_linux_amd64.zip

# Add consul agent
RUN export CONSUL_VERSION=1.0.1 \
    && export CONSUL_CHECKSUM=eac5755a1d19e4b93f6ce30caaf7b3bd8add4557b143890b1c07f5614a667a68 \
    && curl --retry 7 --fail -vo /tmp/consul.zip "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip" \
    && echo "${CONSUL_CHECKSUM}  /tmp/consul.zip" | sha256sum -c \
    && unzip /tmp/consul -d /usr/local/bin \
    && rm /tmp/consul.zip \
    && mkdir -p /etc/consul \
    && mkdir -p /var/lib/consul

# Add ContainerPilot and set its configuration file path
ENV CONTAINERPILOT_VER 3.5.1
ENV CONTAINERPILOT /etc/containerpilot.json5
RUN export CONTAINERPILOT_CHECKSUM=7ee8e59588b6b593325930b0dc18d01f666031d7 \
    && curl -Lso /tmp/containerpilot.tar.gz \
    "https://github.com/joyent/containerpilot/releases/download/${CONTAINERPILOT_VER}/containerpilot-${CONTAINERPILOT_VER}.tar.gz" \
    && echo "${CONTAINERPILOT_CHECKSUM}  /tmp/containerpilot.tar.gz" | sha1sum -c \
    && tar zxf /tmp/containerpilot.tar.gz -C /usr/local/bin \
    && rm /tmp/containerpilot.tar.gz

COPY node_exporter/node_exporter /usr/local/bin/node_exporter

# Add Containerpilot configuration
COPY etc/containerpilot.json5 /etc

# Add Prometheus config template
# ref https://prometheus.io/docs/operating/configuration/
# for details on building your own config
COPY etc/prometheus.yml.ctmpl /etc/prometheus/prometheus.yml.ctmpl

WORKDIR /prometheus
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

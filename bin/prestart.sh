#!/bin/bash

# Do we have env vars for Triton discovery?
# Copy creds from env vars to files on disk
if [ -n "${TRITON_CREDS_PATH}" ] \
    && [ -n "${TRITON_CA}" ] \
    && [ -n "${TRITON_CERT}" ] \
    && [ -n "${TRITON_KEY}" ]
then
    mkdir -p ${TRITON_CREDS_PATH}
    echo -e "${TRITON_CA}" | tr '#' '\n' > ${TRITON_CREDS_PATH}/ca.pem
    echo -e "${TRITON_CERT}" | tr '#' '\n' > ${TRITON_CREDS_PATH}/cert.pem
    echo -e "${TRITON_KEY}" | tr '#' '\n' > ${TRITON_CREDS_PATH}/key.pem
fi

# Set the DC automatically from consul
export TRITON_DC=`cat /etc/consul/consul.hcl | awk 'BEGIN{FS="="}/^datacenter = /{print $2}' | tr -d " \""`

# Create Prometheus config
consul-template -once -consul-addr ${CONSUL}:8500 -template /etc/prometheus/prometheus.yml.ctmpl:/etc/prometheus/prometheus.yml

# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
#

# Stage 1: Build the native image using GraalVM
ARG GRAALVM_VERSION
FROM ghcr.io/graalvm/graalvm-ce:${GRAALVM_VERSION} AS builder
LABEL maintainer="Apache NiFi Registry <dev@nifi.apache.org>"
LABEL site="https://nifi.apache.org"

ARG NIFI_REGISTRY_BINARY
ARG NIFI_REGISTRY_BINARY_NAME
ARG NIFI_REGISTRY_SCRIPTS
ARG NIFI_REGISTRY_VERSION
ARG NIFI_TOOLKIT_BINARY

ENV NIFI_REGISTRY_BASE_DIR /opt/nifi-registry
ENV NIFI_REGISTRY_HOME ${NIFI_REGISTRY_BASE_DIR}/nifi-registry-current
ENV NIFI_TOOLKIT_HOME ${NIFI_REGISTRY_BASE_DIR}/nifi-toolkit-current

# Install required packages
RUN microdnf install -y unzip findutils

# Copy and extract NiFi Registry
ADD $NIFI_REGISTRY_SCRIPTS ${NIFI_REGISTRY_BASE_DIR}/scripts/
RUN chmod -R +x ${NIFI_REGISTRY_BASE_DIR}/scripts/*.sh

COPY $NIFI_REGISTRY_BINARY $NIFI_REGISTRY_BASE_DIR
RUN unzip ${NIFI_REGISTRY_BASE_DIR}/${NIFI_REGISTRY_BINARY_NAME} -d ${NIFI_REGISTRY_BASE_DIR} \
    && rm ${NIFI_REGISTRY_BASE_DIR}/${NIFI_REGISTRY_BINARY_NAME}

COPY $NIFI_TOOLKIT_BINARY $NIFI_REGISTRY_BASE_DIR
RUN unzip ${NIFI_REGISTRY_BASE_DIR}/nifi-toolkit-${NIFI_REGISTRY_VERSION}-bin.zip -d ${NIFI_REGISTRY_BASE_DIR} \
    && rm ${NIFI_REGISTRY_BASE_DIR}/nifi-toolkit-${NIFI_REGISTRY_VERSION}-bin.zip \
    && mv ${NIFI_REGISTRY_BASE_DIR}/nifi-toolkit-${NIFI_REGISTRY_VERSION} ${NIFI_TOOLKIT_HOME}

# Install native-image
RUN gu install native-image

# Configure NiFi Registry for native image
WORKDIR ${NIFI_REGISTRY_BASE_DIR}/nifi-registry-${NIFI_REGISTRY_VERSION}

# Create a native image configuration directory
RUN mkdir -p ${NIFI_REGISTRY_BASE_DIR}/nifi-registry-${NIFI_REGISTRY_VERSION}/native-image-config

# Generate native image configuration by running NiFi Registry with the tracing agent
RUN native-image-configure-launcher \
    --module-path ${NIFI_REGISTRY_BASE_DIR}/nifi-registry-${NIFI_REGISTRY_VERSION}/lib \
    --add-modules ALL-MODULE-PATH \
    --initialize-at-build-time=org.apache.nifi.registry \
    --no-fallback \
    --verbose \
    -H:ConfigurationFileDirectories=${NIFI_REGISTRY_BASE_DIR}/nifi-registry-${NIFI_REGISTRY_VERSION}/native-image-config \
    -H:+ReportExceptionStackTraces \
    -H:Class=org.apache.nifi.registry.NiFiRegistry

# Build the native image
RUN native-image \
    --module-path ${NIFI_REGISTRY_BASE_DIR}/nifi-registry-${NIFI_REGISTRY_VERSION}/lib \
    --add-modules ALL-MODULE-PATH \
    --initialize-at-build-time=org.apache.nifi.registry \
    --no-fallback \
    --verbose \
    -H:ConfigurationFileDirectories=${NIFI_REGISTRY_BASE_DIR}/nifi-registry-${NIFI_REGISTRY_VERSION}/native-image-config \
    -H:+ReportExceptionStackTraces \
    -H:Class=org.apache.nifi.registry.NiFiRegistry \
    -H:Name=nifi-registry-native

# Stage 2: Create the runtime image
FROM debian:slim
LABEL maintainer="Apache NiFi Registry <dev@nifi.apache.org>"
LABEL site="https://nifi.apache.org"

ARG UID=1000
ARG GID=1000
ARG NIFI_REGISTRY_VERSION

ENV NIFI_REGISTRY_BASE_DIR /opt/nifi-registry
ENV NIFI_REGISTRY_HOME ${NIFI_REGISTRY_BASE_DIR}/nifi-registry-current
ENV NIFI_TOOLKIT_HOME ${NIFI_REGISTRY_BASE_DIR}/nifi-toolkit-current

# Setup NiFi Registry user and create necessary directories
RUN groupadd -g ${GID} nifi || groupmod -n nifi `getent group ${GID} | cut -d: -f1` \
    && useradd --shell /bin/bash -u ${UID} -g ${GID} -m nifi \
    && apt-get update \
    && apt-get install -y jq xmlstarlet procps \
    && apt-get -y autoremove \
    && apt-get clean autoclean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy NiFi Registry from the builder stage
COPY --from=builder --chown=nifi:nifi ${NIFI_REGISTRY_BASE_DIR} ${NIFI_REGISTRY_BASE_DIR}
COPY --from=builder --chown=nifi:nifi /app/nifi-registry-native ${NIFI_REGISTRY_BASE_DIR}/nifi-registry-${NIFI_REGISTRY_VERSION}/bin/

RUN ln -s ${NIFI_REGISTRY_BASE_DIR}/nifi-registry-${NIFI_REGISTRY_VERSION} ${NIFI_REGISTRY_HOME} \
    && ln -s ${NIFI_TOOLKIT_HOME} ${NIFI_REGISTRY_BASE_DIR}/nifi-toolkit-${NIFI_REGISTRY_VERSION} \
    && chown -h nifi:nifi ${NIFI_REGISTRY_HOME} ${NIFI_REGISTRY_BASE_DIR}/nifi-toolkit-${NIFI_REGISTRY_VERSION}

USER nifi

# Web HTTP(s) ports
EXPOSE 18080 18443

WORKDIR ${NIFI_REGISTRY_HOME}

# Create a script to start the native image
RUN echo '#!/bin/bash\n\
${NIFI_REGISTRY_HOME}/bin/nifi-registry-native "$@"' > ${NIFI_REGISTRY_HOME}/bin/run-native.sh \
    && chmod +x ${NIFI_REGISTRY_HOME}/bin/run-native.sh

# Apply configuration and start NiFi Registry using the native image
ENTRYPOINT ["bin/run-native.sh"]
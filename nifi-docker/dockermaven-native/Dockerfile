# syntax=docker/dockerfile:1
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
ARG MAINTAINER="Apache NiFi <dev@nifi.apache.org>"
LABEL maintainer="${MAINTAINER}"
LABEL site="https://nifi.apache.org"

ARG NIFI_VERSION
ARG NIFI_BINARY
ARG NIFI_TOOLKIT_BINARY
ARG NIFI_SCRIPTS

ENV NIFI_BASE_DIR /opt/nifi
ENV NIFI_HOME ${NIFI_BASE_DIR}/nifi-current
ENV NIFI_TOOLKIT_HOME ${NIFI_BASE_DIR}/nifi-toolkit-current
ENV NIFI_PID_DIR=${NIFI_HOME}/run
ENV NIFI_LOG_DIR=${NIFI_HOME}/logs

# Install required packages
RUN microdnf install -y unzip findutils

# Copy and extract NiFi
ADD ${NIFI_SCRIPTS} ${NIFI_BASE_DIR}/scripts/
RUN chmod -R +x ${NIFI_BASE_DIR}/scripts/*.sh

COPY $NIFI_BINARY $NIFI_BASE_DIR
RUN unzip ${NIFI_BASE_DIR}/nifi-${NIFI_VERSION}-bin.zip -d ${NIFI_BASE_DIR} \
    && rm ${NIFI_BASE_DIR}/nifi-${NIFI_VERSION}-bin.zip \
    && mv ${NIFI_BASE_DIR}/nifi-${NIFI_VERSION} ${NIFI_HOME} \
    && ln -s ${NIFI_HOME} ${NIFI_BASE_DIR}/nifi-${NIFI_VERSION}

COPY $NIFI_TOOLKIT_BINARY $NIFI_BASE_DIR
RUN unzip ${NIFI_BASE_DIR}/nifi-toolkit-${NIFI_VERSION}-bin.zip -d ${NIFI_BASE_DIR} \
    && rm ${NIFI_BASE_DIR}/nifi-toolkit-${NIFI_VERSION}-bin.zip \
    && mv ${NIFI_BASE_DIR}/nifi-toolkit-${NIFI_VERSION} ${NIFI_TOOLKIT_HOME} \
    && ln -s ${NIFI_TOOLKIT_HOME} ${NIFI_BASE_DIR}/nifi-toolkit-${NIFI_VERSION}

# Create necessary directories
RUN mkdir -p ${NIFI_HOME}/conf \
    && mkdir -p ${NIFI_HOME}/database_repository \
    && mkdir -p ${NIFI_HOME}/flowfile_repository \
    && mkdir -p ${NIFI_HOME}/content_repository \
    && mkdir -p ${NIFI_HOME}/provenance_repository \
    && mkdir -p ${NIFI_HOME}/python_extensions \
    && mkdir -p ${NIFI_HOME}/nar_extensions \
    && mkdir -p ${NIFI_HOME}/state \
    && mkdir -p ${NIFI_LOG_DIR}

# Install native-image
RUN gu install native-image

# Configure NiFi for native image
WORKDIR ${NIFI_HOME}

# Create a native image configuration directory
RUN mkdir -p ${NIFI_HOME}/native-image-config

# Generate native image configuration by running NiFi with the tracing agent
RUN native-image-configure-launcher \
    --module-path ${NIFI_HOME}/lib \
    --add-modules ALL-MODULE-PATH \
    --initialize-at-build-time=org.apache.nifi \
    --initialize-at-run-time=org.apache.nifi.controller.repository.metrics \
    --no-fallback \
    --verbose \
    -H:ConfigurationFileDirectories=${NIFI_HOME}/native-image-config \
    -H:+ReportExceptionStackTraces \
    -H:Class=org.apache.nifi.NiFi

# Build the native image
RUN native-image \
    --module-path ${NIFI_HOME}/lib \
    --add-modules ALL-MODULE-PATH \
    --initialize-at-build-time=org.apache.nifi \
    --initialize-at-run-time=org.apache.nifi.controller.repository.metrics \
    --no-fallback \
    --verbose \
    -H:ConfigurationFileDirectories=${NIFI_HOME}/native-image-config \
    -H:+ReportExceptionStackTraces \
    -H:Class=org.apache.nifi.NiFi \
    -H:Name=nifi-native

# Stage 2: Create the runtime image
FROM debian:slim
ARG MAINTAINER="Apache NiFi <dev@nifi.apache.org>"
LABEL maintainer="${MAINTAINER}"

ARG UID=1000
ARG GID=1000

ENV NIFI_BASE_DIR /opt/nifi
ENV NIFI_HOME ${NIFI_BASE_DIR}/nifi-current
ENV NIFI_TOOLKIT_HOME ${NIFI_BASE_DIR}/nifi-toolkit-current
ENV NIFI_PID_DIR=${NIFI_HOME}/run
ENV NIFI_LOG_DIR=${NIFI_HOME}/logs

# Setup NiFi user and create necessary directories
RUN groupadd -g ${GID} nifi || groupmod -n nifi `getent group ${GID} | cut -d: -f1` \
    && useradd --shell /bin/bash -u ${UID} -g ${GID} -m nifi \
    && apt-get update \
    && apt-get install -y jq xmlstarlet procps \
    && apt-get install -y python3 \
    && apt-get install -y python3-venv \
    && apt-get -y autoremove \
    && apt-get clean autoclean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy NiFi from the builder stage
COPY --from=builder --chown=nifi:nifi ${NIFI_BASE_DIR} ${NIFI_BASE_DIR}
COPY --from=builder --chown=nifi:nifi /app/nifi-native ${NIFI_HOME}/bin/

VOLUME ${NIFI_LOG_DIR} \
       ${NIFI_HOME}/conf \
       ${NIFI_HOME}/database_repository \
       ${NIFI_HOME}/flowfile_repository \
       ${NIFI_HOME}/content_repository \
       ${NIFI_HOME}/provenance_repository \
       ${NIFI_HOME}/python_extensions \
       ${NIFI_HOME}/nar_extensions \
       ${NIFI_HOME}/state

USER nifi

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Clear nifi-env.sh in favour of configuring all environment variables in the Dockerfile
RUN echo "#!/bin/sh\n" > "${NIFI_HOME}/bin/nifi-env.sh"

# Web HTTP(s) & Socket Site-to-Site Ports
EXPOSE 8443/tcp 10000/tcp 8000/tcp

WORKDIR ${NIFI_HOME}

# Create a script to start the native image
RUN echo '#!/bin/bash\n\
${NIFI_HOME}/bin/nifi-native "$@"' > ${NIFI_HOME}/bin/run-native.sh \
    && chmod +x ${NIFI_HOME}/bin/run-native.sh

# Apply configuration and start NiFi using the native image
ENTRYPOINT ["bin/run-native.sh"]
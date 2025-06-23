#!/bin/bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

TAG=$1
VERSION=$2

DOCKER_IMAGE_NAME=apache/nifi-registry:${TAG}

echo "Integration Testing for NiFi Registry Native Docker Image: ${DOCKER_IMAGE_NAME}"

# Start the container
CONTAINER_ID=$(docker run -d -P ${DOCKER_IMAGE_NAME})

# Wait for NiFi Registry to start
echo "Waiting for NiFi Registry to start..."
sleep 30

# Check if the container is running
CONTAINER_STATUS=$(docker inspect -f {{.State.Status}} ${CONTAINER_ID})
if [ "${CONTAINER_STATUS}" != "running" ]; then
    echo "Container is not running. Status: ${CONTAINER_STATUS}"
    docker logs ${CONTAINER_ID}
    docker rm -f ${CONTAINER_ID}
    exit 1
fi

# Get the mapped port for NiFi Registry web UI
REGISTRY_PORT=$(docker port ${CONTAINER_ID} 18080/tcp | cut -d ':' -f 2)

echo "NiFi Registry is running on port ${REGISTRY_PORT}"

# Check if NiFi Registry is responding
echo "Checking if NiFi Registry is responding..."
RETRY_COUNT=0
MAX_RETRIES=10
RETRY_DELAY=5

while [ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]; do
    if curl -s http://localhost:${REGISTRY_PORT}/nifi-registry-api/access > /dev/null; then
        echo "NiFi Registry is responding!"
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ ${RETRY_COUNT} -eq ${MAX_RETRIES} ]; then
        echo "NiFi Registry is not responding after ${MAX_RETRIES} attempts"
        docker logs ${CONTAINER_ID}
        docker rm -f ${CONTAINER_ID}
        exit 1
    fi
    
    echo "Retry ${RETRY_COUNT}/${MAX_RETRIES}. Waiting ${RETRY_DELAY} seconds..."
    sleep ${RETRY_DELAY}
done

# Clean up
docker rm -f ${CONTAINER_ID}

echo "Integration test completed successfully!"
exit 0
# GraalVM Native Docker Images for Apache NiFi and NiFi Registry

This document provides information about the GraalVM-based native Docker images for Apache NiFi and NiFi Registry.

## Overview

GraalVM native images provide several advantages over traditional JVM-based applications:

- **Faster startup time**: Native images start in milliseconds rather than seconds or minutes
- **Lower memory footprint**: Native images use less memory than JVM-based applications
- **Smaller container size**: The resulting Docker images can be significantly smaller
- **Improved performance**: For certain workloads, native images can offer better performance

## Building Native Docker Images

### Apache NiFi Native Docker Image

To build the Apache NiFi native Docker image:

```bash
cd nifi-docker/dockermaven-native
mvn clean package -Pdocker-native
```

This will create a Docker image tagged as `apache/nifi:<version>-native`.

### Apache NiFi Registry Native Docker Image

To build the Apache NiFi Registry native Docker image:

```bash
cd nifi-registry/nifi-registry-docker-maven-native/dockermaven-native
mvn clean package -Pdocker-native
```

This will create a Docker image tagged as `apache/nifi-registry:<version>-native`.

## Running Native Docker Images

### Running NiFi Native Docker Image

```bash
docker run -d -p 8443:8443 apache/nifi:<version>-native
```

### Running NiFi Registry Native Docker Image

```bash
docker run -d -p 18080:18080 apache/nifi-registry:<version>-native
```

## Configuration

Both native Docker images support the same configuration options as their JVM-based counterparts. Environment variables and volume mounts work the same way.

## Technical Implementation

The native Docker images are built using a multi-stage Docker build process:

1. **Stage 1**: Uses GraalVM to compile the Java application into a native executable
2. **Stage 2**: Creates a minimal runtime image with only the necessary components

The build process includes:
- Extracting the NiFi/NiFi Registry binaries
- Installing the GraalVM native-image tool
- Generating native image configuration
- Compiling the application to a native executable
- Creating a minimal runtime image

## Limitations and Considerations

When using GraalVM native images, be aware of the following limitations:

1. **Dynamic Class Loading**: Some dynamic class loading features may be limited
2. **Reflection**: All reflection usage must be properly configured
3. **JVM Features**: Some JVM-specific features may not be available
4. **Compatibility**: Not all plugins or extensions may work with native images

## Performance Tuning

Native images have different performance characteristics compared to JVM-based applications:

- Memory allocation patterns differ
- Garbage collection behavior is different
- Startup time is significantly improved
- Runtime performance may vary depending on the workload

Proper monitoring and tuning are recommended when deploying native images in production environments.
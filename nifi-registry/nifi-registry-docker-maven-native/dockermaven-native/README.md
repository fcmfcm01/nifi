# Apache NiFi Registry GraalVM Native Docker Image

This module provides support for building Apache NiFi Registry as a GraalVM-based native Docker image.

## Overview

The GraalVM native image technology allows for ahead-of-time compilation of Java applications into standalone executables. This results in:

- Faster startup time
- Lower memory footprint
- Smaller container size
- Improved performance for certain workloads

## Building the Native Docker Image

To build the NiFi Registry native Docker image, use the following Maven command:

```bash
mvn clean package -Pdocker-native
```

This will create a Docker image tagged as `apache/nifi-registry:<version>-native`.

## Running the Native Docker Image

You can run the NiFi Registry native Docker image using the standard Docker commands:

```bash
docker run -d -p 18080:18080 apache/nifi-registry:<version>-native
```

## Configuration

The native Docker image supports the same configuration options as the standard NiFi Registry Docker image. Environment variables and volume mounts work the same way.

## Limitations

The GraalVM native image has some limitations compared to the standard JVM-based NiFi Registry:

1. Dynamic class loading may be limited
2. Reflection usage needs to be configured properly
3. Some JVM-specific features may not be available

## Performance Considerations

- The native image has a faster startup time but may have different runtime performance characteristics
- Memory usage patterns differ from the JVM-based version
- Tuning may be required for optimal performance in production environments
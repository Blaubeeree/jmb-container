# Build argument: path to pre-built artifacts (optional)
# If set, COPY pre-compiled JAR and config from this directory instead of building from git
# Usage: docker build --build-arg LOCAL_BUILD_PATH=/build-context .
ARG LOCAL_BUILD_PATH=""

# Stage 1: Build the JMusicBot with Maven and JDK
FROM alpine:3.24 AS builder

LABEL maintainer="chrisb09 <mail@christian-f-brinkmann.de>"

# Install necessary packages including Maven and JDK
RUN apk add --no-cache \
    openjdk11 \
    maven \
    git \
    curl \
    libgcc \
    ca-certificates \
    && rm -rf /var/cache/apk/*

ARG LOCAL_BUILD_PATH=""

# Copy build artifacts from build context if they exist
# (build-context/ dir structure is created by build_docker_image.sh when using --local-build)
COPY build-context/ /tmp/build-context/

# Cache invalidation: forces rebuild from here onwards (timestamp passed by build script)
ARG CACHE_BUST=""
RUN echo "Cache invalidation: ${CACHE_BUST}"

RUN if [ -z "$LOCAL_BUILD_PATH" ]; then \
      git clone --branch dave-fix https://github.com/chrisb09/MusicBot.git /jmb/MusicBot && \
      cd /jmb/MusicBot && \
      mvn clean package -e; \
    else \
      mkdir -p /jmb/MusicBot/target /jmb/MusicBot/src/main/resources && \
      echo "Using local build: copying pre-built artifacts..." && \
      cp /tmp/build-context/target/* /jmb/MusicBot/target/ 2>/dev/null || echo "Note: no JAR files found in build-context"; \
      cp /tmp/build-context/src/main/resources/* /jmb/MusicBot/src/main/resources/ 2>/dev/null || echo "Note: no config files found in build-context"; \
      echo "Build artifacts ready"; \
    fi

# Stage 2: Prepare a minimal runtime environment with just the JRE
FROM alpine:3.24

# Install chromium for PO attestation
RUN apk add --no-cache chromium chromium-chromedriver

# Install the necessary runtime environment (JRE only)
RUN apk add --no-cache openjdk11-jre-headless su-exec tini libgcc ca-certificates

# Copy the compiled jar from builder stage
COPY --from=builder /jmb/MusicBot/target/JMusicBot-*-All.jar /jmb/JMusicBot.jar

# Copy src directory and extract reference.conf if it exists
COPY --from=builder /jmb/MusicBot/src/main/resources/ /jmb/reference/

# Create necessary directories and set permissions
RUN mkdir -p /jmb/config && \
    chmod -R 755 /jmb/config /jmb/reference && \
    chown -R 10000:10001 /jmb/config /jmb/reference

COPY --chmod=755 ./docker-entrypoint.sh /jmb

# Set up volume for external config
VOLUME /jmb/config

# Add user and group
RUN addgroup -S appgroup -g 10001 && \
    adduser -S appuser -G appgroup -u 10000

# Switch to root for entrypoint permissions
USER 0

WORKDIR /jmb/config

ENTRYPOINT ["/sbin/tini", "--", "/jmb/docker-entrypoint.sh"]

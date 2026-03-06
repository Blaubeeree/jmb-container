# Stage 1: Build the JMusicBot with Maven and JDK
FROM alpine:3 AS builder

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


# Clone the repository and build the project
RUN git clone --branch dave-fix https://github.com/chrisb09/MusicBot.git /jmb/MusicBot && \
    cd /jmb/MusicBot && \
    mvn clean package -e

# Stage 2: Prepare a minimal runtime environment with just the JRE
FROM alpine:3

# Install the necessary runtime environment (JRE only)
RUN apk add --no-cache openjdk11-jre-headless su-exec tini libgcc ca-certificates

# Copy the compiled jar from the build stage
COPY --from=builder /jmb/MusicBot/target/JMusicBot-*-All.jar /jmb/JMusicBot.jar
COPY --from=builder /jmb/MusicBot/src/main/resources/reference.conf /jmb/reference/config.txt

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

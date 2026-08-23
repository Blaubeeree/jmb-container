#!/bin/bash
# Build the JMusicBot Docker image
# Options:
#   --no-cache             : Disable Docker build cache
#   --local-build /path    : Use pre-compiled JAR and config from local project path
#                            (path must have target/JMusicBot-*-All.jar and src/main/resources/reference.conf)

NO_CACHE=""
LOCAL_PATH=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_CONTEXT_DIR="$SCRIPT_DIR/build-context"

# Clean up any previous build context
rm -rf "$BUILD_CONTEXT_DIR"
mkdir -p "$BUILD_CONTEXT_DIR/target" "$BUILD_CONTEXT_DIR/src/main/resources"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h|help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --no-cache             Disable Docker build cache"
      echo "  --local-build /path    Use pre-compiled JAR and config from local project path"
      echo "                         (path must have target/JMusicBot-*-All.jar and src/main/resources/reference.conf)"
      exit 0
      ;;
    --no-cache)
      NO_CACHE="--no-cache"
      shift
      ;;
    --local-build)
      LOCAL_PATH="$2"
      if [ ! -d "$LOCAL_PATH" ]; then
        echo "Error: path does not exist: $LOCAL_PATH"
        exit 1
      fi
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# If local build path is provided, copy artifacts to build context
if [ -n "$LOCAL_PATH" ]; then
  echo "Copying build artifacts from $LOCAL_PATH..."
  
  jar_file=$(find "$LOCAL_PATH/target" -name "JMusicBot-*-All.jar" -print -quit)
  if [ -z "$jar_file" ]; then
    echo "Error: JMusicBot-*-All.jar not found in $LOCAL_PATH/target/"
    exit 1
  fi
  cp -v "$jar_file" "$BUILD_CONTEXT_DIR/target/"
  
  ref_conf="$LOCAL_PATH/src/main/resources/reference.conf"
  if [ ! -f "$ref_conf" ]; then
    echo "Error: reference.conf not found at $ref_conf"
    exit 1
  fi
  cp -v "$ref_conf" "$BUILD_CONTEXT_DIR/src/main/resources/"
  
  # Ensure files are flushed to disk before docker build reads them
  sync
  sleep 1
  
  # Verify files are present
  jar_count=$(find "$BUILD_CONTEXT_DIR/target" -name "*.jar" -type f | wc -l)
  conf_count=$(find "$BUILD_CONTEXT_DIR/src/main/resources" -name "*.conf" -type f | wc -l)
  
  if [ "$jar_count" -lt 1 ] || [ "$conf_count" -lt 1 ]; then
    echo "Error: files not properly copied to build context"
    echo "JAR files found: $jar_count (expected 1+)"
    echo "Config files found: $conf_count (expected 1+)"
    ls -la "$BUILD_CONTEXT_DIR/target/"
    ls -la "$BUILD_CONTEXT_DIR/src/main/resources/"
    exit 1
  fi
  
  echo "Verified: $jar_count JAR file(s) and $conf_count config file(s) in build context"
  
  BUILD_ARGS="--build-arg LOCAL_BUILD_PATH=/build-context"
else
  # No local build, but we still need the empty build-context structure for COPY to work
  BUILD_ARGS=""
fi

# Run the build (always pass CACHE_BUST to ensure fresh build from Maven step onwards)
DOCKER_BUILDKIT=1 docker build -t chrisb09/jmusicbot $NO_CACHE --build-arg CACHE_BUST=$(date +%s%N) $BUILD_ARGS . 2>&1 | tee build.log
BUILD_EXIT=$?

# Clean up build context after build completes
rm -rf "$BUILD_CONTEXT_DIR"

if [ $BUILD_EXIT -eq 0 ]; then
  if [ -z "$NO_CACHE" ]; then
    echo "use --no-cache to disable cache"
  fi
  if [ -z "$LOCAL_PATH" ]; then
    echo "use --local-build /path/to/MusicBot to use pre-compiled JAR and config"
  fi
else
  exit $BUILD_EXIT
fi

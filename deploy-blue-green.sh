#!/usr/bin/env bash
set -euo pipefail

APP_NAME="spring-boot-app"
APP_DIR="/home/osboxes/opt/spring-boot-app"

JAVA_OPTS="-Xms512m -Xmx1024m"
SPRING_PROFILE="prod"

BLUE_PORT=8080
GREEN_PORT=8081


BLUE_JAR="app-blue.jar"
GREEN_JAR="app-green.jar"

NEW_JAR_PATH="${1:-}"

if [[ -z "${NEW_JAR_PATH:-}" ]]; then
  echo "Usage: deploy-blue-green.sh <path-to-new-jar>"
  exit 1
fi

cd "$APP_DIR"

echo "================================================"
echo "🚀 Blue-Green Deployment"
echo "================================================"
echo "➡️  New artifact: ${NEW_JAR_PATH}"

#-------------------------------------------------------
#Detect current active environment 
#-------------------------------------------------------

if [[ -f "active-environment" ]]; then
  ACTIVE=$(cat active-environment)
else
    ACTIVE="blue"
fi

echo "ℹ️  Current active environment: $ACTIVE"

#-------------------------------------------------------
#Determine target environment 
#-------------------------------------------------------

if [[ "$ACTIVE" == "blue" ]]; then
  TARGET="green"
  TARGET_PORT="$GREEN_PORT"
  TARGET_JAR="$GREEN_JAR"
else
  TARGET="blue"
  TARGET_PORT="$BLUE_PORT"
  TARGET_JAR="$BLUE_JAR"
fi

echo "ℹ️  Target environment: $TARGET"
echo "ℹ️  Target port: $TARGET_PORT"

#-------------------------------------------------------
#Stop previous instance on target environment
#-------------------------------------------------------

echo "🛑 Stopping previous instance on $TARGET instance"

PID=$(pgrep -f "$TARGET_JAR" || true)

if [[ -n "$PID" ]]; then
  echo "PID=$PID"

  kill "$PID" || true

  for i in {1..15}; do
    if ! kill -0 "$PID" 2>/dev/null; then
      echo "✅ Instance stopped"
      break
    fi

    sleep 1
  done

  if kill -0 "$PID" 2>/dev/null; then
    echo "force stopping instance"
    kill -9 "$PID"
  fi
else
  echo "ℹ️  No previous instance found"
fi

#-------------------------------------------------------
#Backup Previous jar
#-------------------------------------------------------

if [[ -f "$TARGET_JAR" ]]; then

  TIMESTAMP=$(date +%Y%m%d%H%M%S)

  mkdir -p versions

  cp "$TARGET_JAR" \
    "versions/${APP_NAME}-${TARGET}-${TIMESTAMP}.jar"

fi

#-------------------------------------------------------
#Deploy new jar
#-------------------------------------------------------

echo "📦 Installing new artifac"

cp "$NEW_JAR_PATH" "$TARGET_JAR"

chmod 755 "$TARGET_JAR"

#-------------------------------------------------------
#start target instance
#-------------------------------------------------------

echo "▶️  Starting $TARGET instance"

nohup java $JAVA_OPTS \
  -jar "$TARGET_JAR" \
  --spring.profiles.active="$SPRING_PROFILE" \
  --server.port="$TARGET_PORT" \
  > logs/app-$TARGET.log 2>&1 &

TARGET_PID=$!

echo "PID=$TARGET_PID"

#-------------------------------------------------------
#health check
#-------------------------------------------------------

echo "🔍 Waiting for $TARGET instance to become healthy"

HEALTHY=false

for i in {1..20}; do

  if curl -sf \
      "http://localhost:${TARGET_PORT}/health" 
      > /dev/null; then

      echo "✅ $TARGET instance is healthy"

    HEALTHY=true
    break
  fi

  sleep 3
done

#-------------------------------------------------------
#Deployment failed
#-------------------------------------------------------

if [[ "$HEALTHY" != "true" ]]; then

  echo "❌ $TARGET instance failed health check"

  echo "🛑 Stopping failed instance"

  exit 1
fi

#-------------------------------------------------------
#Switch traffic
#-------------------------------------------------------

echo "🔀 Switching traffic to $TARGET"

switch_traffic () {

  echo "⚠️ traffic switched not implemented"
  echo "configure this function for yourload balancer"
}

switch_traffic "$TARGET" "$TARGET_PORT"

#-------------------------------------------------------
#Mark new environment as active
#-------------------------------------------------------

echo "$TARGET" > active-environment

echo "================================================"
echo "Blue-Green Deployment completed "
echo "================================================"
echo "Active environment: $TARGET"
echo "Port: $TARGET_PORT"
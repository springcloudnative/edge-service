#!/bin/sh
set -e
mvn -DskipTests=true \
  org.springframework.boot:spring-boot-maven-plugin:build-image \
  -DREGISTRY_URL=docker.io \
  -DREGISTRY_USERNAME=ernestoacostacuba \
  -DREGISTRY_TOKEN=4ce76d6d-c835-4dc9-9877-6c60d583a05f
if [ "$PUSH_IMAGE" = true ]; then
    docker push "$IMAGE"
fi
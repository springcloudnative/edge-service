#!/bin/bash

declare project_dir=$(dirname $0)
declare registry_url=$1
declare registry_username=$2
declare registry_token=$3

function restart() {
    stop_all
    start_all
}

function start() {
    echo "Starting $1..."
    build_api
    docker-compose up --build --force-recreate -d $1
    docker-compose logs -f
}

function stop() {
    echo "Stopping $1..."
    docker-compose stop $1
    docker-compose rm -f $1
}

function start_infra() {
    echo "Starting polar_mysql_catalog, adminer, catalog-service...."
    docker-compose up --build --force-recreate -d
    docker-compose logs -f
}

function build_image() {
  echo "Building image with Buildpacks....$4"

  if [ -z "$4" ];
  then
    echo "Snapshot version"
      ./mvnw spring-boot:build-image -Premote -DREGISTRY_URL=$1 -DREGISTRY_USERNAME=$2 -DREGISTRY_TOKEN=$3 -DskipTests=true
  else
    ./mvnw spring-boot:build-image -Premote -DREGISTRY_URL=$1 -DREGISTRY_USERNAME=$2 -DREGISTRY_TOKEN=$3  -DimageVersion=$4 -DskipTests=true
  fi
}

function sonarqube_analyze() {
  echo 'Analyzing code with SonarQube....'
  ./mvnw clean verify sonar:sonar -Dsonar.login=$1 -Dsonar.sources=src/main/java/ -Dsonar.java.binaries=target/classes -Dsonar.analysis.mode=publish -DskipTests=true
#  ./mvnw clean package sonar:sonar -Dsonar.host.url=https://sonarcloud.io -Dsonar.organization=$1 -Dsonar.login=$2 -Dsonar.sources=src/main/java/ -Dsonar.java.binaries=target/classes -Dsonar.analysis.mode=publish -Dsonar.branch.name=$3 -DskipTests=true
}

function sonarcloud() {
  echo 'Analyzing code with SonarQube Cloud....'
  ./mvnw clean package sonar:sonar -Psonarcloud -Dsonar.host.url=https://sonarcloud.io -Dsonar.organization=$1 -Dsonar.login=$2 -Dsonar.sources=src/main/java/ -Dsonar.java.binaries=target/classes -Dsonar.analysis.mode=publish -Dsonar.branch.name=$3 -DskipTests=true
}

function start_all() {
    echo 'Removing dangling images....'
    docker rmi $(docker images --filter dangling=true -q)

    echo "Starting all services...."
    if [ "$has_run_build" -eq 1 ];
    then
      build_api
    fi

    docker-compose up --build --force-recreate -d
    docker-compose logs -f
}

function stop_all() {
    echo 'Stopping all services....'
    docker-compose stop
    docker-compose rm -f
    echo 'Removing dangling images....'
    docker rmi $(docker images --filter dangling=true -q)
}

function build_api() {
    mvn clean package -DskipTests
}

action="build_image"

if [[ "$#" != "0"  ]]
then
    action=$@
fi

eval ${action}


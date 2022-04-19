FROM adoptopenjdk/openjdk11:latest AS builder
WORKDIR workspace
ARG JAR_FILE=target/*-SNAPSHOT.jar
COPY ${JAR_FILE} edge-service.jar

RUN java -Djarmode=layertools -jar catalog-service.jar extract


FROM adoptopenjdk/openjdk11:latest
RUN useradd spring
USER spring
WORKDIR workspace

COPY --from=builder workspace/dependencies/ ./
COPY --from=builder workspace/spring-boot-loader/ ./
COPY --from=builder workspace/snapshot-dependencies/ ./
COPY --from=builder workspace/application/ ./

CMD [ "sh", "-c", "java org.springframework.boot.loader.JarLauncher" ]
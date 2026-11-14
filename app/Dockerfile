# One Dockerfile, five JVMs: docker build --build-arg BASE=<image> --build-arg JVM=<name> .
ARG BASE
FROM ${BASE}
ARG JVM
ENV JVM_NAME=${JVM}
WORKDIR /app
COPY target/notes.jar notes.jar
EXPOSE 8080 9091
ENTRYPOINT ["java", "-jar", "notes.jar"]

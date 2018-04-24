ARG MOSQUITTO_VERSION=1.4.12
FROM eclipse-mosquitto:${MOSQUITTO_VERSION}

RUN apk --no-cache add tcl
COPY *.tcl /
COPY *.sh /
ENTRYPOINT ["/docker-entrypoint.sh", "/usr/sbin/mosquitto"]
CMD ["-c", "/mosquitto/config/mosquitto.conf"]
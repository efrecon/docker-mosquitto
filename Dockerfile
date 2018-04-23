ARG MOSQUITTO_VERSION=1.4.12
FROM eclipse-mosquitto:${MOSQUITTO_VERSION}

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh", "/usr/sbin/mosquitto"]
CMD ["-c", "/mosquitto/config/mosquitto.conf"]
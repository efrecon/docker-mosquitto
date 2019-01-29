ARG MOSQUITTO_VERSION=1.4.12
FROM eclipse-mosquitto:${MOSQUITTO_VERSION}

# Install Tcl to be able to run the slicing script, and the root certificates
# bundle. Arrange to rehash the certs so it is possible to connect to remote
# bridges signed "officially".
RUN apk --no-cache add tcl ca-certificates && \
    /etc/ca-certificates/update.d/certhash

# Install tweaking
COPY *.tcl *.sh /

ENTRYPOINT ["/docker-entrypoint.sh", "/usr/sbin/mosquitto"]
CMD ["-c", "/mosquitto/config/mosquitto.conf"]

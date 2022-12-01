ARG MOSQUITTO_VERSION=1.6.15
FROM eclipse-mosquitto:${MOSQUITTO_VERSION}

# Install Tcl to be able to run the slicing script, and the root certificates
# bundle. Arrange to rehash the certs so it is possible to connect to remote
# bridges signed "officially". Also add tini to automatically capture all
# sub-processes and avoid having to force in an init through Docker.
RUN apk --no-cache add tcl ca-certificates tini && \
    /etc/ca-certificates/update.d/certhash

# Install tweaking
COPY *.tcl *.sh /

ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh", "--verbose", "--", "/usr/sbin/mosquitto"]
CMD ["-c", "/mosquitto/config/mosquitto.conf"]

# mosquitto

These Docker [images] behave almost exactly as the official Eclipse [mosquitto]
server [images][official], while providing easy configuration of most parameters
through environment variables. They are also ready for TLS connections using
[official][rootCA] root certificates out-of-the-box. Finally, whenever relevant
files pointed at by the Mosquitto configuration [change](#reloading), this
implementation will [arrange](#reloading) for mosquitto to reload its
configuration to take the changes into account.

  [images]: https://hub.docker.com/r/efrecon/mosquitto
  [mosquitto]: https://eclipse.org/mosquitto
  [official]: https://hub.docker.com/_/eclipse-mosquitto/
  [rootCA]: https://wiki.mozilla.org/CA/Included_Certificates

## Simpler Cases

For all known options present in the default configuration file, it is possible
to set their value through creating an environment variable starting with
`MOSQUITTO_` and continuing with the same name as the option, but in upper case.
So, for example, to change the retry interval to 10 seconds, an interval
controlled by the configuration option `retry_interval`, you would set the
variable `MOSQUITTO_RETRY_INTERVAL` to `10`.

## Sub-Sectioning

This simple heuristic will not work all the time, as Mosquitto divides
configuration files into logical sub-sections and several options within these
sub-sections share the same name. This image provides a workaround based on the
fact that each sub-section is prefixed with a specific comment header in the
default configuration file, a file that is made part of the original image upon
which this image is based. The implementation is currently able to detect the
following sections:

* `default` will contain options for the default listener.
* `extra` will contain options for an additional listener. There is currently
  no support for further listeners.
* `persistence` will contain options for persistence.
* `logging` will contain options for logging.
* `security` will contain options for security, authorisations, ACLs, etc.
* `bridges` will contain options for bridging mosquitto installations together
  for improved scalability.

For example, the content of the `default` section starts with the following
header in the file (up to the next header):

```configure
# =================================================================
# Default listener
# =================================================================
```

To start making use of this sectioning of the configuration file, you **have**
to specify an include directory.  This can be achieved using a configuration
file with a given value for `include_dir`, or by specifying the environment
variable `MOSQUITTO_INCLUDE_DIR`. Whenever the directory is specified, the main
configuration file will be automatically sliced into a number of configuration
files, named as described above and created in the include directory. A backup
of the original configuration file will be made and a new configuration file
where all sub-sections have been removed will be created.

In this context, it becomes possible to use specially crafted environment
variables to address options in the different sub-sections. These variables
should start with `MOSQUITTO__` (note the double underscore), followed by the
name of the section (as in the list above) in uppercase, followed by `__` (two
underscores again), followed by the name of the option in upper case. So, to
specify a different port for the default listener, you could for example, set
`MOSQUITTO_INCLUDE_DIR` to `/mosquitto/config/sections/` to trigger this
mechanism and then set `MOSQUITTO__DEFAULT__PORT` to `2883`.

Note that while logical sections makes it easier to grasp the entire
configuration, some of them are not entirely necessary. For example, the
persistence section does not seem to have option names that clash with other
sections. If you are sure about this, you can set variables directly using
"single" underscores. Consequently, there are, for example two ways of turning
on persistence:

* You could set the variable `MOSQUITTO_PERSISTENCE` to `true` and set the
  variable `MOSQUITTO_PERSISTENCE_LOCATION` to `/mosquitto/data/`
* You could also reason with sections and set the variables
  `MOSQUITTO__PERSISTENCE__PERSISTENCE` and
  `MOSQUITTO__PERSISTENCE__PERSISTENCE_LOCATION`, respectively.

In general, sub-sectioning is more deterministic.

## Using from Compose

These images makes configuration much more visible (and flexible) from compose
files whenever deploying mosquitto containers.  Below is a somewhat constructed
example:

```yaml
volumes:
  persistence:
    driver: local

services:
  mosquitto:
    image: efrecon/mosquitto:1.5.5
    volumes:
      - persistence:/mosquitto/data
    environment:
      - MOSQUITTO_INCLUDE_DIR=/mosquitto/config/sections/
      - MOSQUITTO__PERSISTENCE__AUTOSAVE_ON_CHANGES=true
      - MOSQUITTO__PERSISTENCE__AUTOSAVE_INTERVAL=100
      - MOSQUITTO__PERSISTENCE__PERSISTENCE=true
      - MOSQUITTO__PERSISTENCE__PERSISTENCE_LOCATION=/mosquitto/data/
      - MOSQUITTO__LOGGING__LOG_DEST=stderr
    ports:
      -
        target: 1883
        published: 1883
        protocol: tcp
        mode: host
    logging:
      driver: "json-file"
      options:
        max-size: "1m"
        max-file: "10"
    deploy:
      restart_policy:
        delay: 10s
        max_attempts: 10
        window: 60s
      replicas: 1
```

Jumping into the container with `docker exec` would show a modified version of
the regular configuration file at `/mosquitto/config/mosquitto.conf` and several
configuration files in the directory `/mosquitto/config/sections/`, one for each
of the sections supported by this implementation.

## Complex Cases

For even more complex cases, you will have to provide your own configuration
file by hand. If this is the case, there is probably little point in preferring
this image over the official Eclipse image. However, you might still want to mix
behaviours. As long as you provide a configuration that contains the same
sections (in comments) as the original configuration file, you should be able to
benefit from this implementation. Note that the entrypoint requires the file to
be located at `/mosquitto/config/mosquitto.conf`.

## Security

### Secrets

For security reasons, you would probably not want to expose the value of secrets
using environment variables. A possible workaround is to copy the default
configuration file inside your own project, modify sensitive data in the file
and mount it/copy it into the container.  As long as your copy keeps track of
all possible options and their default values as lines that are commented away,
you would still be able to tune the configuration externally as explained in the
previous paragraph. Note that most secret information in mosquitto is offloaded
to other files than the main configuration file, so in most cases you will be
safe to point at these files through environment variables; while still making
sure that the files containing secret information are present within the
container.

### TLS

In order to provide TLS encryption, you will have to add an extra listener to
mosquitto. Provided you have official key and cert for a host, you could place
them in a volume (`tls` in the example below) and adapt the following compose
file:

```yaml
volumes:
  persistence:
    driver: local
  tls:
    driver: local

services:
  mosquitto:
    image: efrecon/mosquitto:1.5.5
    volumes:
      - persistence:/mosquitto/data
      - tls:/mosquitto/config/security
    environment:
      - MOSQUITTO_INCLUDE_DIR=/mosquitto/config/sections/
      - MOSQUITTO__PERSISTENCE__AUTOSAVE_ON_CHANGES=true
      - MOSQUITTO__PERSISTENCE__AUTOSAVE_INTERVAL=100
      - MOSQUITTO__PERSISTENCE__PERSISTENCE=true
      - MOSQUITTO__PERSISTENCE__PERSISTENCE_LOCATION=/mosquitto/data/
      - MOSQUITTO__LOGGING__LOG_DEST=stderr
      - MOSQUITTO__EXTRA__LISTENER=8883
      - MOSQUITTO__EXTRA__CAPATH=/etc/ssl/certs/
      - MOSQUITTO__EXTRA__KEYFILE=/mosquitto/config/security/yourhostname.key
      - MOSQUITTO__EXTRA__CERTFILE=/mosquitto/config/security/yourhostname.crt
    ports:
      -
        target: 8883
        published: 8883
        protocol: tcp
        mode: host
    logging:
      driver: "json-file"
      options:
        max-size: "1m"
        max-file: "10"
    deploy:
      restart_policy:
        delay: 10s
        max_attempts: 10
        window: 60s
      replicas: 1
```

This can be combined with an auto-renewing reverse proxy such as [caddy] to
protect access to your mosquitto container using certificates from
[Let's Encrypt][LE]. You will then have to share the volume where [caddy]
stores handshaked certificates with your mosquitto container and adapt the
path to access the key and certificate.

  [caddy]: https://caddyserver.com/
  [LE]: https://letsencrypt.org/

## Configuring the Entrypoint

The entrypoint itself can be configured either by command-line options, or
through environment variables, all starting with `MQ_`. Command-line options
have precedence over environment variables. The image default is to provide
feedback about the transformations applied by this implementation through
setting the `--verbose` flag.

## Reloading

When running with sectioning, which is triggered by setting the environment
variable `MOSQUITTO_INCLUDE_DIR` or setting the configuration parameter
`include_dir`, this implementation is able to detect changes in files that are
pointed at by the configuration, e.g. password file, server certificate or key,
etc. This is controlled by the command-line option `--watcher` to the entrypoint
(or the environment variable `MQ_WATCHER`); a good default that should work in
most cases is provided.

The implementation will look into the sectioned configuration files for the
values of known configuration parameters and, for each, start a process that
will watch the file pointed at by the parameter for changes. When the file
changes, the `SIGHUP` process is sent to mosquitto, which will then reload its
configuration (see section about signals in the [manual]).

File watching is implemented using [`watch.sh`][watch], signalling using
[`signal.sh`][signal]. The signalling implementation will actively look for a
probable process if the PID file does not exist.

  [watch]: ./watch.sh
  [signal]: ./signal.sh
  [manual]: https://mosquitto.org/man/mosquitto-8.html

## Automated Builds

Builds will happen automatically for all current and future versions of the
official [images] by the way of the scripts in the [hooks] directory. This means
that versioning and tagging of these images will match the official Docker
library. Currently, version discovery is based on [reg-tags], a shell library
present as a submodule to this repository.

  [hooks]: https://github.com/efrecon/docker-mosquitto/tree/master/hooks
  [reg-tags]: https://github.com/efrecon/reg-tags

## Implementation

All substitution and slicing occurs from [docker-entrypoint.sh]. Substitution in
the various configuration files occurs at the shell level. Slicing the main
configuration file into sub-sections required a more complex algorithm and is
implemented in the Tcl script [slicer.tcl]. The script is called twice, once for
detecting the location of the include directory, and a second time to create the
various sub-section files.

Configuration of the entrypoint can occur through environment variables starting
with `MQ_`. The value of these variables is also used in the processes that are
started from the entrypoint to watch relevant files for changes. The entire
process tree forming the implementation is placed under the control of [tini] to
ease garbage collection of processes when containers are killed or stopped.

  [docker-entrypoint.sh]: https://github.com/efrecon/docker-mosquitto/blob/master/docker-entrypoint.sh
  [slicer.tcl]: https://github.com/efrecon/docker-mosquitto/blob/master/slicer.tcl
  [tini]: https://github.com/krallin/tini

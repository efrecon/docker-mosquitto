# Example

This directory presents an example Docker compose file that exhibits a large
number of the features provided by this image on top of the official Mosquitto
image:

* The version of the base image used is driven by the build argument
  `MOSQUITTO_VERSION`.
* Division into sections is triggered through setting the environment variable
  `MOSQUITTO_INCLUDE_DIR`.
* The value of a number of configuration parameters is set in these sections
  through setting a number of environment variables starting with `MOSQUITTO__`
  (note the double underscore).
* A simplistic ACL file is given to the container and pointed at by the
  mosquitto configuration, as a result of setting the environment variable
  `MOSQUITTO__SECURITY__ACL_FILE`. As mosquitto generate log messages when
  reloading its configuration, it is possible to edit the file and witness when
  the configuration is reloaded for testing purposes.

You should run `docker-compose` with the `--compatibility` option to create and
run an example container.

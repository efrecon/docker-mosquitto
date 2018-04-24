# mosquitto

These images behaves almost exacly as the official Eclipse mosquitto server
images, while providing easy configuration of most parameters through
environment variables.

## Simpler Cases

For all known options present in the default configuration file, it is possible
to set their value through creating an environment variable starting with
`MOSQUITTO_` and continuing with the same name as the option, but in upper case.
So, for example, to change the retry interval to 10 seconds, you would set the
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
* `listener` will contain options for an additional listener. There is currently
  no support for further listeners.
* `persistence` will contain options for persistence.
* `logging` will contain options for logging.
* `security` will contain options for security, authorisations, ACLs, etc.
* `bridges` will contain options for bridging mosquitto installations together
  for improved scalability.

To make use of this sectioning of the configuration file, you will have to
specify an include directory.  This can be achieved through using a
configuration file with a given value for `include_dir`, or by specifying the
environment variable `MOSQUITTO_INCLUDE_DIR`. Whenever the directory is
specified, the main configuration file will be automatically sliced into a
number of configuration files, named as described above and created in the
include directory. A backup of the original configuration file will be made and
a new configuration file where all sub-sections have been removed will be
created.

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

## Complex Cases

For even more complex cases, you will have to provide your own configuration
file by hand. If this is the case, there is probably little point in preferring
this image over the official Eclipse image. However, you might still want to mix
behaviours. As long as you provide a configuration that contains the same
sections (in comments) as the original configuration file, you should be able to
benefit from this implementation. Note that the entrypoint requires the file to
be located at `/mosquitto/config/mosquitto.conf`.

## Security

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

## Automated Builds

Builds will happen automatically for all current and future versions of the
official [image](https://hub.docker.com/_/eclipse-mosquitto/) by the way of the
scripts in [hooks/](hooks/). This means that versioning and tagging of these
images will match the official Docker library. Currently, version discovery
uses scraping of the docker hub.

## Implemenation

All substitution and slicing occurs from
[docker-entrypoint.sh](docker-entrypoint.sh). Substitution in the various
configuration files occurs at the shell level. Slicing the main configuration
file into sub-sections required a more complex algorithm and is implemented in
the Tcl script [slicer.tcl](slicer.tcl). The script is called twice, once for
detecting the location of the include directory, and a second time to create the
various sub-section files.
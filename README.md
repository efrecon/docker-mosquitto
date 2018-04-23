# mosquitto

These images behaves almost exacly as the official Eclipse mosquitto server
images, while providing easy configuration of most parameters through
environment variables.

For all known options present in the default configuration file, it is possible
to set their value through creating an environment variable starting with
`MOSQUITTO_` and continuing with the same name as the option, but in upper case.
So, for example, to turn on persistence, you would set the variable
`MOSQUITTO_PERSISTENCE` to `true` and set the variable
`MOSQUITTO_PERSISTENCE_PATH` to `/mosquitto/data/`.

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
scripts in [hooks/](hooks/). This means that versioning and taggine of these
images will match the official Docker library.
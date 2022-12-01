# Docker-Mosquitto

**Docker-Mosquitto** is a Docker image providing a convenience wrapper on top of [Mosquitto]. It is supports setting Mosquitto [configuration] via environment variables that can then be passed via Docker (and Docker Compose).

[mosquitto]: https://eclipse.org/mosquitto
[configuration]: https://mosquitto.org/man/mosquitto-conf-5.html

To learn more about it, see [the base repo README](/core.readme.md).

## Limitations of the "efrecon/docker-mosquitto" Docker image

The _efrecon/docker-mosquitto_ image is a robust solution for a typical MQTT broker setup. It works by setting environment variable values in Mosquitto configuration upon container run. After all configuration update is done, it then runs the official Mosquitto [image] under the hood.

[image]: https://hub.docker.com/_/eclipse-mosquitto/

The key limitation is the lack of support for multiple same-key configuration such as **bridge topics**. This is due to how configuration via environment variables is performed. It is done by substituting (using `sed`) the configured values with the passed key-value pairs (built from the environment variables). This make it impossible to set multiple same-key configurations.

If we have the following topic configuration, for example:

```yaml
version: '3.1'

services:
  sample:
    image: .../docker-mosquitto:latest
    environment:
        - ...
        - MOSQUITTO__BRIDGES__TOPIC=topic # both 0
        - MOSQUITTO__BRIDGES__TOPIC=topic $SYS/# both 0
        - ...
    ...
...

```

Only the `$SYS` topic will be set overwritting the previous `#` topic set.

## Improvement

Additional work was done to make it suitable for a use case: MQTT server running in bridge mode.

We've made the `dokcer-mosquitto` be able to accept file path containing topics. This way, the user can set the topics they want and Mosquitto will accept them so long as they follow the topic rules (`topic pattern [[[ out | in | both ] qos-level] local-prefix remote-prefix]`) which can be found in the Mosquitto manual.

## Usage

### Setting single bridge topics

Single topics can be set by following the [base docker-mosquitto guide](/core.readme.md#using-from-compose).

### Setting multiple bridge topics

To set multiple bridge topics, only a topic list file (`topic-list`) _with content_ is necessary. It is also important to **not have the `MOSQUITTO__BRIDGES__TOPIC` configuration set** as well.

1. Create a topic list file
2. Pass it as a volume in Docker
3. Set the value of `TOPICS_FILE` configuration option to the path of the topic list file

Example with Docker Compose:

```yaml
version: '3.1'

services:
  sample:
    image: .../docker-mosquitto:latest
    environment:
      - ...
      - TOPICS_FILE=/mosquitto/topics/topic-list
    volumes:
      - ...
      - ./mosquitto/topics:/mosquitto/topics
    ...
```

Example topic list:

```
topic # both 0
topic $SYS/# both 0
```

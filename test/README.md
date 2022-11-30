# About testing the script files

Testing is done via the [Bats](https://github.com/bats-core/bats-core) library wrapped in a Docker image.

The test directory contains the tests. Note that only features we've added are covered by the tests.

The command to run test container from project root directory is as follows:

```shell
docker run -it -v "${PWD}:/code" bats/bats:latest test  
```

This launches an unnamed container with the project directory passed as a volume. Could set the name (e.g. `--name bats-unit-test`) if desired.
#!/usr/bin/env bats

setup() {
  # Get the containing directory of this file
  #
  # Use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
  # as those will point to the bats executable's location or the preprocessed file respectively
  DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
  # Make scripts visible to PATH for convenience
  PATH="$DIR/../.:$PATH"
}

@test "Topics are added to target file" {
  bridge-topic.sh "test/mosquitto/topics/topic-list" "test/mosquitto/topics/bridge.snippet.conf"
  # Check that the contennts of the topics file can be found in the config file
  topicListContent=$(cat test/mosquitto/topics/topic-list)
  grep "${topicListContent}" test/mosquitto/topics/bridge.snippet.conf
  [ $? == 0 ]
}

@test "Fails if no topic is passed" {
  (bridge-topic.sh) ||
    (
      # Assert that the script exited with TOPIC_NOT_SET_CODE (41) error
      [ $? == 41 ]
    )
}

@test "Fails if topic file is empty" {
  (bridge-topic.sh "test/mosquitto/topics/empty-topic-list" "test/mosquitto/topics/bridge.snippet.conf") ||
    (
      # Assert that the script exited with TOPIC_EMPTY_CODE (45) error
      [ $? == 45 ]
    )
}

@test "Fails if topic file does not exist" {
  (bridge-topic.sh "test/mosquitto/topics/unknown-topic-list" "test/mosquitto/topics/bridge.snippet.conf") ||
    (
      # Assert that the script exited with TOPIC_FILE_NOT_FOUND_CODE (44) error
      [ $? == 44 ]
    )
}

@test "Fails if configuration file is not specified" {
  (bridge-topic.sh "test/mosquitto/topics/topic-list") ||
    (
      # Assert that the script exited with BRIDGE_CONF_NOT_SET_CODE (42) error
      [ $? == 42 ]
    )
}

@test "Fails if configuration file does not exist" {
  (bridge-topic.sh "test/mosquitto/topics/topic-list" "test/mosquitto/topics/bridge.unknown.conf") ||
    (
      # Assert that the script exited with BRIDGE_CONF_FILE_NOT_FOUND_CODE (43) error
      [ $? == 43 ]
    )
}

teardown() {
  # Remove any added lines to the bridge.snippet.conf file
  sed -i -e '/^#topic/,/^# .*/{/^#topic/!{/^# .*/!d;};}' "test/mosquitto/topics/bridge.snippet.conf"
}

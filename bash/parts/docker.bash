#!/bin/bash

# Commands to kill, start and restart (kill + start) docker. Helps clean up memory.
killDocker() { killall Docker; }
startDocker() { open -a Docker; }
restartDocker() { killDocker && startDocker; }

# Kills all running docker containers.
alias killAllDockerContainers='docker rm -f $(docker ps -aq) >/dev/null 2>&1 || true'

# Removes all docker containers. This does not use the force flag, so some images may require manual deletion.
removeAllDockerContainers() { docker image rm $(docker image ls | awk '{print $3}'); }

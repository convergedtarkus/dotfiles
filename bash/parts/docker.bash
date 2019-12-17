#!/usr/bin/env bash

# Commands to kill, start and restart (kill + start) docker. Helps clean up memory.
killDocker() { killall Docker; }
startDocker() { open -g -a Docker; } # -g will not focus Docker when it starts.
restartDocker() {
	if killDocker >/dev/null 2>&1; then
		echo "Docker was killed"
	else
		echo "Docker was not running"
	fi

	echo "Starting Docker"
	startDocker
}

# Kills all running docker containers.
alias killAllDockerContainers='docker rm -f $(docker ps -aq) >/dev/null 2>&1 || true'

# Removes all docker containers. This does not use the force flag, so some images may require manual deletion.
removeAllDockerContainers() { docker image rm "$(docker image ls | awk '{print $3}')"; }

dockerStop() {
	if [[ -n "$(docker ps -aq)" ]]; then
		echo "Stop all containers."
		docker stop "$(docker ps -a -q)"
		echo "All containers stopped."
	else
		echo "No docker containers running"
	fi
}

dockerKill() {
	if [[ -n "$(docker ps -aq)" ]]; then
		echo "Killing all stuck containers."
		docker rm -f "$(docker ps -aq)" >/dev/null 2>&1 || true
		echo "All containers dead."
	else
		echo "No docker containers to kill."
	fi
}

nukeDocker() {
	dockerStop

	echo
	echo "Pruning system."
	docker system prune --all --force --volumes

	echo
	dockerKill

	echo
	if [[ -n $(docker images -q) ]]; then
		echo "Deleting all docker images."
		docker rmi "$(docker images -q)"
	else
		echo "No docker images to delete."
	fi

	echo
	echo "Deleting all volumes."
	rm -rf /var/lib/docker/volumes/*
	rm -rf /var/lib/docker/vfs/dir/*

	echo
	echo "Kill and restart docker"
	restartDocker

	echo
	if [[ -d "$HOME/Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux/Docker.qcow2" ]]; then
		echo "Delete Library/Containers/ docker stuff."
		rm "$HOME/Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux/Docker.qcow2"
	else
		echo "No docker stuff under Library/Containers/"
	fi

	echo
	echo
	printf "\033[1;32mFinished nuking!\033[0m\n"
}

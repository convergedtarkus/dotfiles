#!/usr/bin/env bash

# Commands to kill, start and restart (kill + start) docker. Helps clean up memory.
killDocker() { killall Docker; }
startDocker() { open -g -a Docker; } # -g will not focus Docker when it starts.
restartDocker() { killDocker && startDocker; }

# Kills all running docker containers.
alias killAllDockerContainers='docker rm -f $(docker ps -aq) >/dev/null 2>&1 || true'

# Removes all docker containers. This does not use the force flag, so some images may require manual deletion.
removeAllDockerContainers() { docker image rm "$(docker image ls | awk '{print $3}')"; }

dockerStop() {
	echo "Stop all containers"
	docker stop $(docker ps -a -q)
	echo "All containers stopped"
}

dockerKill() {
	echo "Killing all stuck containers"
	docker rm -f $(docker ps -aq) >/dev/null 2>&1 || true
	echo "All containers dead"
}

nukeDocker() {
	dockerStop

	echo
	echo "Pruning system"
	docker system prune --all --force --volumes

	echo
	echo "Delete all containers"
	docker rm -f $(docker ps -a -q) >/dev/null 2>&1 || true

	echo
	echo "Delete all images"
	docker rmi $(docker images -q)

	echo
	echo "Delete all volumes"
	rm -rf /var/lib/docker/volumes/*
	rm -rf /var/lib/docker/vfs/dir/*

	echo
	echo "Kill and restart docker"
	killall Docker && open /Applications/Docker.app

	echo
	echo "Delete Final Docker Shiz"
	rm ~/Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux/Docker.qcow2

	echo
	echo
	echo "Finished nuking"
}

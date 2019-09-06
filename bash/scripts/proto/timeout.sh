#!/usr/bin/env bash

# waits a given time, and if the given PID is still running, kills it.
# arg 1 = time to wait in seconds.
# arg 2 = the PID to check/kill.
waitThenKill() {
	sleepTime="$1"
	commandToKillPID="$2"
	sleep $sleepTime
	if kill -0 $commandToKillPID &>/dev/null; then
		echo "Sleeping command is still running, killing it."
		kill -9 $commandToKillPID
	fi
}

SECONDS=0
commandTime=$(((RANDOM % 5) + 1))
waitTime=$(((RANDOM % 5) + 1))
echo "Command time: $commandTime Wait time: $waitTime"
echo

sleep $commandTime && echo "Command had finished!" &
commandPID=$!

# TODO What if process is already done??
waitThenKill $waitTime $commandPID &
waitThenKillPID=$!

wait $commandPID &>/dev/null
if [[ $? -eq 0 ]]; then
	echo "Command completed in time, kill waitThenKill"
	kill -9 $waitThenKillPID
fi
echo "Seconds passed: $SECONDS"

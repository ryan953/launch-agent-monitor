#!/bin/bash
# BGMonitor demo LaunchAgent script.
# Prints a timestamped greeting using an argument passed in via
# ProgramArguments (falling back to $USER) plus an EnvironmentVariables
# value set in the plist, to demonstrate both mechanisms.

NAME="${1:-$USER}"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

echo "[$TIMESTAMP] hello $NAME — ${DEMO_GREETING:-(DEMO_GREETING not set)}"

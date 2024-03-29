#!/bin/sh

# Start all process describe in ENV variables.
# The process running in subshell.

echo "${CRONTAB} /app/source/authentication >> /dev/null 2>&1" > /scheduler.crond

/usr/bin/crontab /scheduler.crond

LISTEN="STARTUP_COMMAND_RUN"

printenv | more | grep "${LISTEN}" | while read -r line ; do
  sh -c "${line#*=}" &
done

# Naive check runs checks once a minute to see if either of the processes exited.
# This illustrates part of the heavy lifting you need to do if you want to run
# more than one service in a container. The container exits with an error
# if it detects that either of the processes has exited.
# Otherwise it loops forever, waking up every 60 seconds

runner() {
    echo "Stop this container."
    kill -SIGINT 1
}

trap runner SIGINT SIGQUIT SIGTERM

/bin/mount -t cifs -o username=${DOMAIN_USERNAME},domain=${DOMAIN},password=${DOMAIN_PASSWORD} ${DOMAIN_SHARED} ${DFOLDER}

while sleep 8 & wait $!; do

  if ! mountpoint -q -- "${DFOLDER}"; then
    runner
  fi

  printenv | more | grep "${LISTEN}" | while read -r line ; do

    # Grep process status

    process="${line#*=}"
    ps aux | grep "${process%% *}" | grep -v grep > /dev/null

    # If the greps above find anything, they exit with 0 status
    # If they are not both 0, then something is wrong

    if [ $? -ne 0 ] ; then
      echo "The processes ${process} already exited."
      runner
    fi

  done

done

#!/bin/sh
# Note: I've written this using sh so it works in the busybox container too

# USE the trap if you need to also do manual cleanup after the service is stopped,
#     or need to start multiple services in the one container
trap "echo TRAPed signal" HUP INT QUIT KILL TERM

echo "Starting postgres" >> /var/log/runService.log

# start service in background here
invoke-rc.d postgresql start

/usr/app/saneRoster/bin/app.pl > /var/log/dancer.log 2>&1

# stop service and clean up here
echo "Stopping postgres" >> /var/log/runService.log
invoke-rc.d postgresql stop

echo "exited $0" >> /var/log/runService.log
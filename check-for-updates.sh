#!/bin/bash

source /srv/homeassistant/bin/activate

if [ `grep -c homeassistant <<< $(pip list --outdated --format freeze)` -ge 1 ]; then
  echo 1
else
  echo 0
fi

exit 0
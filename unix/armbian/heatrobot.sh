#!/bin/bash

TEMP_MIN=15
TEMP_MAX=24

DELAY_OFF=60
DELAY_ON=600

DELAY_OFF=6
DELAY_ON=60


function errtrap {     es=$?;     echo "$0: line $1: Command exited with status $es.">&2; }; trap 'errtrap $LINENO' ERR
set -eE
set -o pipefail

coproc HUNGP {
  read x || true
}

mysleep() {
  read -t "${1:?}" <&"${HUNGP[0]}" || [ $? = 142 ]
}






while true; do

echo reading from HUNGP
mysleep 0.2

done

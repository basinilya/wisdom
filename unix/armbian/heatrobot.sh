#!/bin/bash

TEMP_MIN=15000
TEMP_MAX=24000

DELAY_OFF=60
DELAY_ON=600

EMULATE=yes

if [ x"$EMULATE" = x"yes" ]; then
  DELAY_OFF=6
  DELAY_ON=60
fi

coproc HUNGP {
  read x || true
}

trap 'set_on; echo status="on" set, now exiting' EXIT
function errtrap {     es=$?;     echo "$0: line $1: Command exited with status $es.">&2; }; trap 'errtrap $LINENO' ERR
set -eE
set -o pipefail

mysleep() {
  read -t "${1:?}" <&"${HUNGP[0]}" || [ $? = 142 ]
}

STATUS_OK=0
STATUS_FAIL=1

if [ x"$EMULATE" = x"yes" ]; then

  get_temp() {
    local _temp
    read _temp
    temp=$((_temp - 0))
    if [ $temp = 0 && x"$_temp" != x"0" ]; then
      >&2 echo "Invalid integer vailue: $_temp"
      false
      exit 1
    fi
    echo "temp=$temp"
  }
  
  set_off() {
    :
  }
  
  set_on() {
    :
  }
  
  is_on() {
    return $STATUS_OK
  }

fi


if is_on; then
  :
else
  :
fi

get_temp


while true; do


echo reading from HUNGP
mysleep 0.2

done

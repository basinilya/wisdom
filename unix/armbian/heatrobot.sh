#!/bin/bash

stty sane

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

STATUS_OK=0
STATUS_FAIL=1

mysleep() {
  read -t "${1:?}" <&"${HUNGP[0]}" || [ $? = 142 ]
}

set_on() {
  :
}

kill_kbd() {
  :
}

tty_settings=`stty -g`
trap 'set +e; set_on; kill_kbd 2>/dev/null; stty "$tty_settings"; echo status="on" set, now exiting' EXIT
stty -icanon -echo

KBD_PID=

if [ x"$EMULATE" = x"yes" ]; then
  echo 20 >/dev/shm/heatrobot-temp

  {
    echo use arrow keys now...
    # 1b5b44 left
    # 1b5b43 right
    # 1b5b41 up
    # 1b5b42 down
    
    while read -r -d "" -n 1 c; do
      if [ "$c" = $'\x1b' ]; then
        read -r -d "" -n 1 c || break
        if [ "$c" = $'[' ]; then
          read -r -d "" -n 1 c || break
          case $c in
          $'\x41'|$'\x43') # up or right
            echo up or right
            ;;
          $'\x42'|$'\x44') # down or left
            echo down or left
            ;;
          esac
        fi
      fi
      # printf '%s' "$c" | xxd
      
    done
    
    # xxd -p
  } <&0 &
  KBD_PID=$!
  kill_kbd() {
    kill $KBD_PID
    wait $KBD_PID
  }
fi

sleep 10

exit 0


function errtrap {     es=$?;     echo "$0: line $1: Command exited with status $es.">&2; }; trap 'errtrap $LINENO' ERR
set -eE
set -o pipefail



if [ x"$EMULATE" = x"yes" ]; then

  get_temp() {
    local _temp
    read _temp </dev/shm/heatrobot-temp
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

else
  >&2 echo "Not implemented"
  false
  exit 1
fi # EMULATE


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

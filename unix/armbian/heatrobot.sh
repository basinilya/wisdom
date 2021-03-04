#!/bin/bash

stty sane

TEMP_MIN=15000
TEMP_MAX=24000

DELAY_OFF=60
DELAY_ON=600

EMULATE=yes

if [ x"$EMULATE" = x"yes" ]; then
  DELAY_OFF=6
  DELAY_ON=10
fi

coproc HUNGP {
  read x || true
}

STATUS_OK=0
STATUS_FAIL=1

_mysleep() {
  read -t "${1:?}" <&"${HUNGP[0]}" || [ $? = 142 ]
}


mysleep() {
  echo "sleeping ${1:?}s"
  _mysleep "$@"
}

exec 4<&0

set_on() {
  :
}

kill_kbd() {
  :
}

trap 'set +e; set_on; kill_kbd; echo status="on" set, now exiting' EXIT
function errtrap {     es=$?;     echo "$0: line $1: Command exited with status $es.">&2; }; trap 'errtrap $LINENO' ERR
set -e
set -o pipefail

if [ x"$EMULATE" = x"yes" ]; then

  get_temp() {
    local _temp
    read _temp </dev/shm/heatrobot-temp
    temp=$((_temp - 0))
    if [ $temp = 0 -a x"$_temp" != x"0" ]; then
      >&2 echo "Invalid integer vailue: $_temp"
      false
      exit 1
    fi
    #echo "temp=$temp"
  }

  echo 20000 >/dev/shm/heatrobot-temp

  iftty=
  tty_settings=`stty -g` || iftty=:
  $iftty stty -icanon -echo

  kill_kbd() {
    {
      kill $KBD_PID
      wait $KBD_PID
    } 2>/dev/null
    # if interrupted during `read` built-in command then ERR trap stdin is the `read` input.
    $iftty stty "$tty_settings" <&4
  }

  KBD_PID=
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
            get_temp
            temp=$((temp + 1000))
            echo "new temp: $temp"
            echo $temp >/dev/shm/heatrobot-temp
            ;;
          $'\x42'|$'\x44') # down or left
            get_temp
            temp=$((temp - 1000))
            echo "new temp: $temp"
            echo $temp >/dev/shm/heatrobot-temp
            ;;
          esac
        fi
      fi
      # printf '%s' "$c" | xxd
      
    done
  } <&0 &
  KBD_PID=$!

  set_off() {
    power_status=$STATUS_FAIL
  }
  
  set_on() {
    power_status=$STATUS_OK
  }
  
  is_on() {
    return $power_status
  }

  set_on
  
else
  >&2 echo "Not implemented"
  false
  exit 1
fi # EMULATE

exec 0<&-

# set -E # inherit ERR trap

while true; do
  if is_on; then
    mysleep $DELAY_ON
  else
    mysleep $DELAY_OFF
  fi
  
  while true; do
    get_temp
    
    if is_on; then
      if [ $temp -gt $TEMP_MAX ]; then
        echo "temp=$temp too high, powering off"
        set_off
        break
      else
        echo "temp=$temp is ok, keep power on"
      fi
    else
      if [ $temp -lt $TEMP_MIN ]; then
        echo "temp=$temp too low, powering on"
        set_on
        break
      else
        echo "temp=$temp is ok, keep power off"
      fi
    fi
    
    _mysleep 2
  done
done

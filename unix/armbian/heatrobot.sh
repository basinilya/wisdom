#!/bin/bash

# Usage: heatrobot.sh | ( trap '' INT; ts )
# OR
# as a systemd service

# Millidegrees Celsius
TEMP_MIN=19000
TEMP_MAX=28000

# Seconds
DELAY_COOLOFF=450
DELAY_WARMUP=900
CHECK_PERIOD=120

EMULATE=
#EMULATE=yes

if [ x"$EMULATE" = x"yes" ]; then
  DELAY_COOLOFF=5
  DELAY_WARMUP=10
  CHECK_PERIOD=2
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

  WPI_PIN=9

  gpio mode "${WPI_PIN:?}" OUT

  get_temp() {
    temp=$(< /sys/bus/w1/devices/28-00000c71ddc0/temperature)
  }
  
  set_off() {
    :
    gpio write "${WPI_PIN:?}" 1
  }

  set_on() {
    gpio write "${WPI_PIN:?}" 0
  }
  
  is_on() {
    local res;
    res=$(gpio read "${WPI_PIN:?}")
    return $res
  }

fi # EMULATE

exec 0<&-

# set -E # inherit ERR trap

while true; do
  if is_on; then
    echo "power is initially on"
    mysleep $DELAY_WARMUP
  else
    echo "power is initially off"
    mysleep $DELAY_COOLOFF
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
    
    _mysleep "$CHECK_PERIOD"
  done
done

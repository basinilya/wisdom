#!/bin/bash

# Turn switch off and on when temperature not within range.
#
# Usage: heatrobot.sh 2>&1 | ( trap '' INT; ts )
# OR
# as a systemd service

# Millidegrees Celsius
TEMP_MIN=19000
TEMP_MAX=28000

# Seconds
DELAY_COOLOFF=450
DELAY_WARMUP=900
CHECK_PERIOD=120

# see: `gpio readall`
WPI_PIN=9

# Must be either a persistent device path or its hwmon symlink like: /sys/class/hwmon/hwmon[0-9]*/device
BLACKLIST_SENSORS=(
  /sys/devices/virtual/thermal/thermal_zone0
  #/sys/bus/w1/devices/28-00000c71ddc0
  #/sys/class/hwmon/hwmon0/device
  #/sys/class/hwmon/hwmon1/device
)


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
      >&2 echo "Invalid integer value: $_temp"
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

  gpio mode "${WPI_PIN:?}" OUT

  get_temp() {
    local d canon h _temp
    local -A BLACKLIST_SENSORS_CANON
    BLACKLIST_SENSORS_CANON=()
    
    shopt -s nullglob
    for d in "${BLACKLIST_SENSORS[@]}"; do
      #echo "add blacklisted: $d"
      if ! canon=$(readlink -f "$d"); then
        >&2 echo "path check failed for $d"
        continue
      fi
      for h in "$canon"/hwmon[0-9]*/temp1_input "$canon"/hwmon/hwmon[0-9]*/temp1_input; do
        #echo "found temp1_input as: $h"
        BLACKLIST_SENSORS_CANON["$h"]=x
        continue 2
      done
      >&2 echo "failed to find temp1_input for $d"
    done
    
    temp=999999
    shopt -s nullglob
    for d in /sys/class/hwmon/hwmon[0-9]*/temp1_input; do
      #echo "checking temperature of: $d"
      canon=$(readlink -f "$d")
      if [[ -v "BLACKLIST_SENSORS_CANON[$canon]" ]]; then
        :
        #echo "is blacklisted"
      else
        _temp=$(< "$d")
        if [ "$temp" -gt "$_temp" ]; then
          temp=$_temp
        fi
      fi
    done
  
    # if no sensors, then power must always be on
    if [ 999999 = "$temp" ]; then
      >&2 echo "No sensors found"
      temp=-999999
    fi  
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

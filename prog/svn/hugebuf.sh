#!/bin/bash
set -e
host=${1:?}
port=${2:?}

WAITCMD=
NAME="<"

fn_cleanup() {
  >&2 echo "$NAME cleanup"
  exec 4>&-
  $WAITCMD
  >&2 echo "$NAME exiting"
}

fn_wait_graceful() {
  >&2 echo "$NAME received EOF; waiting for the other side"
  sleep 60 &
  wait -n $OTHERPID $!
  kill -KILL $OTHERPID $! 2>/dev/null || true
}

# TODO: do not use -KILL, otherwise a grandchild may survive
fn_kill() {
  >&2 echo "$NAME read failed; killing the other side"
  kill -KILL $OTHERPID 2>/dev/null || true
}

OTHERPID=$$

>&2 echo "connecting to ${host:?}:${port}"
exec 4>"/dev/tcp/${host:?}/${port}"


# TODO: do not use `wait`, use coproc and read with timeout to confirm the other side death
{
  NAME=">"
  WAITCMD=fn_kill
  trap 'fn_cleanup' EXIT
  # unlike cat socat will hopefully shutdown the socket instead of closing it
  socat -u FD:0 FD:1,shut-down <&0 >&4
  fn_wait_graceful() {
    >&2 echo "$NAME received EOF; waiting for the other side"
    for ((i=0;i<60;i++)); do
      kill -0 $OTHERPID 2>/dev/null || return
      sleep 1
    done
    kill -KILL $OTHERPID 2>/dev/null || true
  }
  WAITCMD=fn_wait_graceful
} <&0 &
OTHERPID=$!

trap 'fn_cleanup' EXIT

WAITCMD=fn_kill

pv -q -C -B4G <&4
socat -u FD:0 FD:1,shut-down </dev/null
WAITCMD=fn_wait_graceful

#!/bin/bash

old_version="$1"
new_version="$2"

migrations=$( GET_MIGRATIONS "${installed_version}" "${this_version}" )
if [ -n "${migrations}" ]; then
  printf 'Make sshGate version migrations'
  for migration in ${migrations}; do
    [ -n "${migration}" ] && eval "${migration}"
    if [ $? -ne 0 ]; then
      printf ' ... KO\n%s' "An error occured will upgrading sshGate"
      exit 1
    fi
  done
  printf ' ... OK\n'
fi
exit 0

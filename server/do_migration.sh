#!/bin/bash

old_version="$1"
new_version="$2"

migrations=$( GET_MIGRATIONS "${installed_version}" "${this_version}" )
if [ -n "${migrations}" ]; then
  DOTHIS 'Make sshGate version migrations'
  for migration in ${migrations}; do
    [ -n "${migration}" ] && eval "${migration}"
    if [ $? -ne 0 ]; then
      KO "An error occured will upgrading sshGate"
      exit 1
    fi
  done
  OK
fi

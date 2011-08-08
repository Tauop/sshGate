#!/bin/bash
#
# Copyright (c) 2010 Linagora
# Patrick Guiran <pguiran@linagora.com>
# http://github.com/Tauop/sshGate
#
# sshGate is free software, you can redistribute it and/or modify
# it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License, or (at your option) any later version.
#
# sshGate is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# load dependencies
load() {
  local var= value= file=

  var="$1"; file="$2"
  value=$( eval "echo \"\${${var}:-}\"" )

  [ -n "${value}" ] && return 1;
  if [ -f "${file}" ]; then
    . "${file}"
  else
    echo "ERROR: Unable to load ${file}"
    exit 2
  fi
  return 0;
}

# Load configuration file
if [ -r /etc/ScriptHelper.conf ]; then
  . /etc/ScriptHelper.conf
  SCRIPT_HELPER_DIRECTORY="${SCRIPT_HELPER_DIRECTORY:-}"
  SCRIPT_HELPER_DIRECTORY="${SCRIPT_HELPER_DIRECTORY%%/}"
else
  SCRIPT_HELPER_DIRECTORY='./lib'
fi

if [ ! -d "${SCRIPT_HELPER_DIRECTORY}/" ]; then
  echo "[ERROR] sshGate depends on ScriptHelper which doesn't seem to be installed"
  exit 2
fi

load __LIB_MESSAGE__ "${SCRIPT_HELPER_DIRECTORY}/message.lib.sh"
load __LIB_ASK__     "${SCRIPT_HELPER_DIRECTORY}/ask.lib.sh"

# ----------------------------------------------------------------------------
version=
ASK version "sshgate version ?"

# build are used for testing :-) (can be empty)
build=
ASK --allow-empty build "sshGate build number ?"

include_script_helper='N'
if [ "${action}" = 'all' -o "${action}" = 'server' ]; then
  ASK --yesno include_script_helper 'Include ScriptHelper in package ?'
fi

# ----------------------------------------------------------------------------

DOTHIS 'Build sshgate-server package'
  softname=sshGate-server-${version}
  [ -n "${build}" ] && softname="${softname}-${build}"
  dir="/tmp/${softname}"

  [ -d "${dir}/" ] && rm -rf "${dir}/"
  mkdir "${dir}/"

  # for MacOS X and its fucking ._files
  export COPYFILE_DISABLE=true

  cp -r ./  "${dir}/"
  if [ "${include_script_helper}" = 'Y' ]; then
    cp -r ./lib  ${dir}/
  fi

  # specific action for package built with build.sh script
  find "${dir}/build-utils" -name "*.sh" -exec mv {} "${dir}/" ';'
  mv "${dir}/build-utils/bin/sshgate-configure" "${dir}/bin/sshgate-configure"
  mv "${dir}/build-utils/bin/core/setup.func"   "${dir}/bin/core/setup.func"
  rm -rf "${dir}/build-utils/"

  # clean up
  find "${dir}/" -name "sshGate-server-*.tar.gz" | xargs rm -f
  find "${dir}/" -type f -iname '*swp' | xargs rm -f
  find "${dir}/" -type f -iname '.*'   | xargs rm -f
  find "${dir}/" -iname '.git'         | xargs rm -rf

  # put version and build number
  sed_repl=
  sed_repl="${sed_repl} s|%% __SSHGATE_VERSION__ %%|${version}|;"
  sed_repl="${sed_repl} s|%% __SSHGATE_BUILD__ %%|${build}|;"

  sed -e "${sed_repl}" < "${dir}/install.sh"        > "${dir}/install.sh.sed"
  sed -e "${sed_repl}" < "${dir}/data/sshgate.conf" > "${dir}/sshgate.conf.sed"
  mv "${dir}/install.sh.sed"   "${dir}/install.sh"
  mv "${dir}/sshgate.conf.sed" "${dir}/data/sshgate.conf"

  chmod +x "${dir}/install.sh"

  cd /tmp
  tar -z -c -f "${softname}.tar.gz" "${softname}" 2>/dev/null >/dev/null
  cd - >/dev/null

  mv "${dir}.tar.gz" .
  rm -rf "${dir}"
OK

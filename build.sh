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

action='all'
if [ $# -ne 0 ]; then
  [ "$1" = 'client' ] && action='client'
  [ "$1" = 'server' ] && action='server'
fi


# Load configuration file
if [ -r /etc/ScriptHelper.conf ]; then
  . /etc/ScriptHelper.conf
  SCRIPT_HELPER_DIRECTORY="${SCRIPT_HELPER_DIRECTORY:-}"
  SCRIPT_HELPER_DIRECTORY="${SCRIPT_HELPER_DIRECTORY%%/}"
else
  SCRIPT_HELPER_DIRECTORY='./lib'
fi

if [ ! -d "${SCRIPT_HELPER_DIRECTORY}/" ]; then
  echo "ERROR: sshGate depends on ScriptHelper which doesn't seem to be installed"
  exit 2
fi

. "${SCRIPT_HELPER_DIRECTORY}/message.lib.sh"
. "${SCRIPT_HELPER_DIRECTORY}/ask.lib.sh"
. "${SCRIPT_HELPER_DIRECTORY}/exec.lib.sh"

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

if [ "${action}" = 'all' -o "${action}" = 'client' ]; then
  DOTHIS 'Build sshgate-client package'
    dir=/tmp/sshGate-client-${version}
    [ -n "${build}" ] && dir="${dir}-${build}"

    [ -d ${dir}/ ] && CMD rm -rf ${dir}/
    CMD mkdir ${dir}/
    CMD mkdir ${dir}/lib/

    CMD cp COPYING              ${dir}/
    CMD cp -r ./client/*        ${dir}/
    CMD cp ./lib/ask.lib.sh     ${dir}/lib/
    CMD cp ./lib/message.lib.sh ${dir}/lib/
    CMD cp ./lib/random.lib.sh  ${dir}/lib/

    CMD chmod +x ${dir}/install.sh
    CMD chmod +x ${dir}/sshg
    CMD chmod +x ${dir}/scpg

    CMD tar c --transform "'s|^tmp/||S'" -z -f ${dir}.tar.gz ${dir} 2>/dev/null

    CMD mv ${dir}.tar.gz .
    CMD rm -rf ${dir}
  OK
fi

if [ "${action}" = 'all' -o "${action}" = 'server' ]; then
  DOTHIS 'Build sshgate-server package'
    softname=sshGate-server-${version}
    [ -n "${build}" ] && softname="${softname}-${build}"
    dir=/tmp/${softname}

    [ -d ${dir}/ ] && CMD rm -rf ${dir}/
    CMD mkdir ${dir}/

    CMD cp COPYING              ${dir}/
    CMD cp -r ./server/*        ${dir}/
    if [ "${include_script_helper}" = 'Y' ]; then
      CMD cp -r ./lib           ${dir}/
    fi

    # put version and build number
    sed_repl=
    sed_repl="${sed_repl} s|%% __SSHGATE_VERSION__ %%|${version}|;"
    sed_repl="${sed_repl} s|%% __SSHGATE_BUILD__ %%|${build}|;"

    sed -e "${sed_repl}" < "${dir}/install.sh"   > "${dir}/install.sh.sed"
    sed -e "${sed_repl}" < "${dir}/sshgate.conf" > "${dir}/sshgate.conf.sed"
    mv "${dir}/install.sh.sed"   "${dir}/install.sh"
    mv "${dir}/sshgate.conf.sed" "${dir}/sshgate.conf"

    CMD chmod +x ${dir}/install.sh

    CMD find ${dir}/ -type f -iname "*swp" -exec rm -f {} '\;'
    CMD 'find ${dir}/ -iname ".git" | xargs rm -rf'

    cd /tmp
    CMD tar -z -c -f ${softname}.tar.gz ${softname} 2>/dev/null
    cd - >/dev/null

    CMD mv ${dir}.tar.gz .
    CMD rm -rf ${dir}
  OK
fi

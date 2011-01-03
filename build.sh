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

. ./lib/message.lib.sh
. ./lib/ask.lib.sh
. ./lib/exec.lib.sh

version=
ASK version "sshgate version ? "

build=
ASK build "sshGate build number ?"

action='all'
if [ $# -ne 0 ]; then
  [ "$1" = 'client' ] && action='client'
  [ "$1" = 'server' ] && action='server'
fi

if [ "${action}" = 'all' -o "${action}" = 'client' ]; then
  DOTHIS 'Build sshgate-client package'
    dir=/tmp/sshGate-client_${version}
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
    dir=/tmp/sshGate-server_${version}
    [ -n "${build}" ] && dir="${dir}-${build}"

    [ -d ${dir}/ ] && CMD rm -rf ${dir}/
    CMD mkdir ${dir}/
    CMD mkdir ${dir}/lib/

    CMD cp COPYING              ${dir}/
    CMD cp -r ./server/*        ${dir}/
    CMD cp ./lib/ask.lib.sh     ${dir}/lib/
    CMD cp ./lib/message.lib.sh ${dir}/lib/
    CMD cp ./lib/conf.lib.sh    ${dir}/lib/
    CMD cp ./lib/mail.lib.sh    ${dir}/lib/
    CMD cp ./lib/cli.lib.sh     ${dir}/lib/
    CMD cp ./lib/random.lib.sh  ${dir}/lib/

    # put version and build number
    sed_repl=
    sed_repl="${sed_repl} s|%% __SSHGATE_VERSION__ %%|${version}|;"
    sed_repl="${sed_repl} s|%% __SSHGATE_BUILD__ %%|${build}|;"

    sed -i -e "${sed_repl}" "${dir}/install.sh"
    sed -i -e "${sed_repl}" "${dir}/sshgate.conf"

    CMD chmod +x ${dir}/install.sh

    CMD find ${dir}/ -type f -iname "*swp" -exec rm -f {} '\;'
    CMD tar c --transform "'s|^tmp/||S'" -z -f ${dir}.tar.gz ${dir} 2>/dev/null

    CMD mv ${dir}.tar.gz .
    CMD rm -rf ${dir}
  OK
fi

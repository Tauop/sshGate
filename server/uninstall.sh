#!/bin/bash
#
# Copyright (c) 2010 Linagora
# Patrick Guiran <pguiran@linagora.com
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

# don't want to add exec.lib.sh in dependencies :/
user_id=`id -u`
[ "${user_id}" != "0" ] \
  && KO "You must execute $0 with root privileges"

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
  SCRIPT_HELPER_DIRECTORY='./lib/'
fi

if [ ! -d "${SCRIPT_HELPER_DIRECTORY}" ]; then
  echo "ERROR: sshGate depends on ScriptHelper which doesn't seem to be installed"
  exit 2
fi

load __LIB_RANDOM__  "${SCRIPT_HELPER_DIRECTORY}/random.lib.sh"
load __LIB_MESSAGE__ "${SCRIPT_HELPER_DIRECTORY}/message.lib.sh"
load __LIB_ASK__     "${SCRIPT_HELPER_DIRECTORY}/ask.lib.sh"
load __LIB_CONF__    "${SCRIPT_HELPER_DIRECTORY}/conf.lib.sh"

# for configuration (SETUP_CONFIGURE and SETUP_GET_DIRECTORIES)
[ -r ./bin/core/setup.func ] && . ./bin/core/setup.func

BR
WARNING "Uninstallation will remove all data and files sshGate installed and created"
ASK --yesno reply "Are you sure [N] ?" 'N'

if [ "${reply}" = 'N' ]; then
  BR
  MESSAGE "Canceled !"
  BR
fi

CONF_SET_FILE /etc/sshgate.conf
CONF_LOAD

# delete all data
for dir in $( SETUP_GET_DIRECTORY_VARIABLES ); do
  rm -rf "$( eval "echo \"\${${dir}}\"" )"
done

# delete sshGate Unix user
home_dir=$( cat /etc/passwd | grep "^${user}:" | cut -d':' -f6 )
userdel "${SSHGATE_GATE_ACCOUNT}"
[ -d "${home_dir}" ] && rm -rf "${home_dir}"

# remove sshGate sudoer entry
file="/tmp/file.$(RANDOM)"
grep -v "^${SSHGATE_GATE_ACCOUNT} " < /etc/sudoers > "${file}"
mv "${file}" /etc/sudoers
chmod 0440 /etc/sudoers

# delete global configuration
rm -f /etc/sshgate.conf

BR
MESSAGE "sshGate is uninstalled"
BR
exit 0

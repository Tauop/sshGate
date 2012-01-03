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
load __SETUP_FUNC__  "./bin/core/setup.func"
# [ -r ./bin/core/setup.func ] && . ./bin/core/setup.func

# for migrations
[ -r ./upgrade.sh ] && . ./upgrade.sh

# ----------------------------------------------------------------------------

action='install'          # install | update
install_script_helper='N' # when ScriptHelper is bundled in the package, install it ?
configure='yes'           # yes | no. when action=update, it can be 'no'
this_version=             # version of this package (set by build.sh)
installed_version=        # version of installed sshgate

# ----------------------------------------------------------------------------
CONF_SET_FILE "./data/sshgate.conf"
CONF_LOAD

BR
MESSAGE "   --- sshGate server installation ---"
MESSAGE "            by Patrick Guiran"
BR

if [ -r /etc/sshgate.conf ]; then
  action='update'
  MESSAGE "It seems that sshGate is already installed on your system."
  ASK --yesno reply \
      "Do you want to re-use the installed configuration [Y] ?" \
      'Y'
  [ "${reply}" = 'Y' ] && configure='no'

  # get installed version and this package version to know wether
  # we have to make migration (update sshGate internal data)
  CONF_GET --conf-file ./data/sshgate.conf SSHGATE_VERSION this_version
  CONF_GET --conf-file /etc/sshgate.conf   SSHGATE_VERSION installed_version

  # old version of sshGate hasn't a SSHGATE_VERSION conf variable
  [ -z "${installed_version}" ] && installed_version='0'
fi

if [ "${configure}" = 'yes' ]; then
  # ScriptHelper dependency
  if [ -r /etc/ScriptHelper.conf ]; then
    CONF_GET --conf-file /etc/ScriptHelper.conf SCRIPT_HELPER_DIRECTORY
  elif [ "${action}" = 'install' ]; then
    if [ ! -d ./lib/ ]; then
      ERROR "sshGate depends on ScriptHelper which doesn't seem to be installed"
      exit 1;
    fi
    BR
    NOTICE "ScriptHelper will be installed as part of sshGate, not system-wide"
    MESSAGE "If you want to install ScriptHelper system-wide, please visit http://github.com/Tauop/ScriptHelper"
    BR
    install_script_helper='Y'
  fi
  CONF_SAVE SCRIPT_HELPER_DIRECTORY

  # configure sshGate installation
  # sh ./bin/sshgate-configure --silent configure ./data/sshgate.conf
  SETUP_CONFIGURE ./data/sshgate.conf

fi # end of : if [ "${configure}" = 'yes' ]; then

# ----------------------------------------------------------------------------
BR ; BR

if [ "${action}" = 'update' ]; then
  chmod +x ./do_migration.sh
  ./do_migration.sh "${installed_version}" "${this_version}"
fi

DOTHIS 'Reload configuration'
  # reset loaded configuration and reload it
  if [ "${configure}" = 'yes' ]; then
    CONF_LOAD
  else
    CONF_SET_FILE "/etc/sshgate.conf"
    CONF_SAVE SSHGATE_VERSION "${this_version}"
    CONF_LOAD
  fi
  # load sshGate setup for constants
  load __SSHGATE_SETUP__ './data/sshgate.setup'
OK


DOTHIS 'Installing sshGate'
  if [ "${action}" = 'install' ]; then

    # create directories
    MK () { [ ! -d "$1/" ] && mkdir -p "$1"; }
    for dir in $( SETUP_GET_DIRECTORY_VARIABLES ); do
      MK "$( eval "echo \"\${${dir}}\"" )"
    done

    # Create sshGate unix account
    grep "^${SSHGATE_GATE_ACCOUNT}:" /etc/passwd >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
      useradd "${SSHGATE_GATE_ACCOUNT}" 2>/dev/null
      if [ $? -ne 0 ]; then
        echo "ERROR: Can't create ${SSHGATE_GATE_ACCOUNT} unix account"
        exit 1;
      fi
    fi

    # Create sshGate unix group
    grep "^${SSHGATE_GATE_ACCOUNT}:" /etc/group >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
      groupadd "${SSHGATE_GATE_ACCOUNT}" 2>/dev/null
      if [ $? -ne 0 ]; then
        echo "ERROR: Can't create ${SSHGATE_GATE_ACCOUNT} unix account"
        exit 1;
      fi
    fi

    home_dir=$( cat /etc/passwd | grep "^${SSHGATE_GATE_ACCOUNT}:" | cut -d':' -f6 )
    MK "${home_dir}/.ssh/"
  fi

  # install stuff
  cp -r ./bin/ ./data/ COPYING "${SSHGATE_DIRECTORY}/"
  [ -d ./tests/ ] && cp -r ./tests/ "${SSHGATE_DIR_BIN}/"

  if [ "${action}" = 'install' -a "${install_script_helper}" = 'Y' ]; then
    cp -r ./lib/   "${SSHGATE_DIR_BIN}/"
  elif [ "${action}"  = 'update' ]; then
    if [ -d ./lib/ -a -d "${SSHGATE_DIR_BIN}/lib/" ]; then
      cp -r ./lib/   "${SSHGATE_DIR_BIN}/"
    fi
  fi

  if [ "${configure}" = 'yes' ]; then
    cp ./data/sshgate.conf /etc/sshgate.conf
  fi
OK


if [ ! -f "${SSHGATE_TARGET_DEFAULT_PRIVATE_SSHKEY_FILE}" ]; then
  DOTHIS 'Generate default sshkey pair'
  # generate targets default sshkey
    ssh-keygen -C "sshGate key" -t rsa -b 4096 -N '' -f "${SSHGATE_TARGET_DEFAULT_PRIVATE_SSHKEY_FILE}" >/dev/null
    mv "${SSHGATE_TARGET_DEFAULT_PRIVATE_SSHKEY_FILE}.pub" "${SSHGATE_TARGET_DEFAULT_PUBLIC_SSHKEY_FILE}"
  OK
fi

DOTHIS 'Setup files permissions'
  SETUP_UPDATE_PERMISSIONS
OK

DOTHIS 'Install archive cron'
  mv "${SSHGATE_DIR_BIN}/archive-log.sh" /etc/cron.monthly/
  chmod +x /etc/cron.monthly/archive-log.sh
OK

if [ "${SSHGATE_USE_REMOTE_ADMIN_CLI}" = 'Y' -a "${action}" = 'install' ]; then
  DOTHIS 'configure /etc/sudoers'
    file="/tmp/sudoers.${RANDOM}"
    [ "${SSHGATE_SUDO_WITH_NOPASSWORD}" = 'Y' ] && sudo_no_passwd='NOPASSWD:' || sudo_no_passwd=''
    grep -v "^${SSHGATE_GATE_ACCOUNT} " < /etc/sudoers > "${file}"
    mv "${file}" /etc/sudoers
    echo "${SSHGATE_GATE_ACCOUNT} ALL=(root) ${sudo_no_passwd}${SSHGATE_DIR_BIN}/sshgate-cli" >> /etc/sudoers
    chmod 0440 /etc/sudoers
    rm -f "${file}"
  OK
fi

if [ -z "$( ls -1 "${SSHGATE_DIR_USERS}" )" ]; then
  # FIXME: ugly => load all sshGate, like the CLI :-(
  __SSHGATE_SETUP__=
  SSHGATE_DIRECTORY=
  . "${SSHGATE_DIR_DATA}/sshgate.setup"
  . "${SSHGATE_DIR_CORE}/sshgate.core"

  BR
  MESSAGE "You need to add the first user of sshGate, which will be sshGate administrator."
  MESSAGE "This user will allow you to manage other users, targets and accesses."

  ASK user "user login ?"
  ASK mail "user mail ?"

  USER_ADD "${user}" "${mail}"
  USER_SET_CONF "${user}" IS_ADMIN      'true'
  USER_SET_CONF "${user}" IS_RESTRICTED 'false'
  BR
  MESSAGE "In order to administrate sshGate, just ssh this host with this user"
  MESSAGE "  If you have installed sshGate client -> sshg cli"
  MESSAGE "  with standard ssh client -> ssh -t ${SSHGATE_GATE_ACCOUNT}@$(hostname) cli"
  MESSAGE "  from this terminal -> ${SSHGATE_DIR_BIN}/sshgate-cli -u ${user}"
fi

BR
NOTICE "You may add ${SSHGATE_DIR_BIN} in your PATH variable"
BR

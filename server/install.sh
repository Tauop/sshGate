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

[ -r ./upgrade.sh ] && . ./upgrade.sh

# don't want to add exec.lib.sh in dependencies :/
user_id=`id -u`
[ "${user_id}" != "0" ] \
  && KO "You must execute $0 with root privileges"

# ----------------------------------------------------------------------------

action='install'          # install | update
install_script_helper='N' # when ScriptHelper is bundled in the package, install it ?
configure='yes'           # yes | no. when action=update, it can be 'no'
this_version=             # version of this package (set by build.sh)
installed_version=        # version of installed sshgate

# ----------------------------------------------------------------------------
CONF_SET_FILE "./sshgate.conf"
CONF_LOAD

BR
MESSAGE "   --- sshGate server configuration ---"
MESSAGE "             by Patrick Guiran"
BR

if [ -r /etc/sshgate.conf ]; then
  action='update'
  MESSAGE "It seems that sshGate is already installed on your system."
  ASK --yesno reply \
      "Do you want to re-use the installed configuration [Y] ?" \
      'Y'
  [ "${reply}" = 'Y' ] && configure='no'

  CONF_GET --conf-file ./sshgate.conf    SSHGATE_VERSION this_version
  CONF_GET --conf-file /etc/sshgate.conf SSHGATE_VERSION installed_version

  # old version of sshGate hasn't a SSHGATE_VERSION conf variable
  [ -z "${installed_version}" ] && installed_version='0'
fi

if [ "${configure}" = 'yes' ]; then
  ASK SSHGATE_DIRECTORY \
      "Where do you want to install sshGate [${SSHGATE_DIRECTORY}] ? " \
      "${SSHGATE_DIRECTORY}"
  CONF_SAVE SSHGATE_DIRECTORY

  ASK SSHGATE_GATE_ACCOUNT \
      "Which unix account to use for sshGate users [${SSHGATE_GATE_ACCOUNT}] ? " \
      "${SSHGATE_GATE_ACCOUNT}"
  CONF_SAVE SSHGATE_GATE_ACCOUNT

  ASK SSHGATE_TARGETS_DEFAULT_SSH_LOGIN \
      "What the default user account to use when connecting to target host [${SSHGATE_TARGETS_DEFAULT_SSH_LOGIN}] ? " \
      "${SSHGATE_TARGETS_DEFAULT_SSH_LOGIN}"
  CONF_SAVE SSHGATE_TARGETS_DEFAULT_SSH_LOGIN

  ASK --yesno SSHGATE_MAIL_SEND \
      "Activate mail notification system [Yes] ?" \
      "Y"
  [ "${SSHGATE_MAIL_SEND}" = 'N' ] && SSHGATE_MAIL_SEND='false'
  if [ "${SSHGATE_MAIL_SEND}" = 'Y' ]; then
    SSHGATE_MAIL_SEND='true'
    ASK SSHGATE_MAIL_TO \
        "Who will receive mail notification (comma separated mails) [${SSHGATE_MAIL_TO}] ?" \
        "${SSHGATE_MAIL_TO}"
    [ -z "${SSHGATE_MAIL_TO}" ] && SSHGATE_MAIl_SEND='false'
  else
    SSHGATE_MAIL_SEND='false'
  fi
  CONF_SAVE SSHGATE_MAIL_SEND
  CONF_SAVE SSHGATE_MAIL_TO

  ASK --yesno SSHGATE_USERS_MUST_ACCEPT_CGU \
      "Do users have to accept CGU when connecting for the first time [${SSHGATE_USERS_MUST_ACCEPT_CGU}] ? " \
      "${SSHGATE_USERS_MUST_ACCEPT_CGU}"
  CONF_SAVE SSHGATE_USERS_MUST_ACCEPT_CGU

  ASK --yesno SSHGATE_ALLOW_REMOTE_COMMAND \
      "Allow remote command [${SSHGATE_ALLOW_REMOTE_COMMAND}] ? " \
      "${SSHGATE_ALLOW_REMOTE_COMMAND}"

  sudo_no_passwd=''
  if [ "${SSHGATE_ALLOW_REMOTE_COMMAND}" = 'Y' ]; then
    ASK --yesno SSHGATE_USE_REMOTE_ADMIN_CLI \
        "Allow remote administration CLI [${SSHGATE_USE_REMOTE_ADMIN_CLI}] ? " \
        "${SSHGATE_USE_REMOTE_ADMIN_CLI}"
    if [ "${SSHGATE_USE_REMOTE_ADMIN_CLI}" = 'Y' ]; then
      ASK --yesno sudo_no_passwd "Configure sudo with NOPASSWD to launch remote admin CLI [No] ?" 'N'
    fi
  fi
  CONF_SAVE SSHGATE_ALLOW_REMOTE_COMMAND
  CONF_SAVE SSHGATE_USE_REMOTE_ADMIN_CLI

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
    SCRIPT_HELPER_DIRECTORY="${SSHGATE_DIRECTORY}/bin/lib"
    install_script_helper='Y'
  fi
  CONF_SAVE SCRIPT_HELPER_DIRECTORY

fi # end of : if [ "${configure}" = 'yes' ]; then

# ----------------------------------------------------------------------------
BR ; BR

if [ "${action}" = 'update' ]; then
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
    MK "${SSHGATE_DIRECTORY}"
    MK "${SSHGATE_DIR_USERS}"
    MK "${SSHGATE_DIR_TARGETS}"
    MK "${SSHGATE_DIR_USERS_GROUPS}"
    MK "${SSHGATE_DIR_LOGS_TARGETS}"
    MK "${SSHGATE_DIR_LOGS_USERS}"
    MK "${SSHGATE_DIR_ARCHIVE}"

    grep "^${SSHGATE_GATE_ACCOUNT}:" /etc/passwd >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
      useradd "${SSHGATE_GATE_ACCOUNT}"
      home_dir=$( cat /etc/passwd | grep "^${SSHGATE_GATE_ACCOUNT}:" | cut -d':' -f6 )

      MK "${home_dir}/.ssh/"
      chmod 755 "${home_dir}"
      chown "${SSHGATE_GATE_ACCOUNT}" "${home_dir}"
      chown "${SSHGATE_GATE_ACCOUNT}" "${home_dir}/.ssh"
    fi
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
    cp ./sshgate.conf /etc/sshgate.conf
  fi
OK

DOTHIS 'Generate default sshkey pair'
  # generate targets default sshkey
  if [ ! -f "${SSHGATE_TARGET_DEFAULT_PRIVATE_SSHKEY_FILE}" ]; then
    ssh-keygen -C "sshGate key" -t rsa -b 4096 -N '' -f "${SSHGATE_TARGET_DEFAULT_PRIVATE_SSHKEY_FILE}" >/dev/null
    mv "${SSHGATE_TARGET_DEFAULT_PRIVATE_SSHKEY_FILE}.pub" "${SSHGATE_TARGET_DEFAULT_PUBLIC_SSHKEY_FILE}"
  fi
OK

DOTHIS 'Setup files permissions'
  chown -R "${SSHGATE_GATE_ACCOUNT}" "${SSHGATE_DIRECTORY}"
  chown -R root "${SSHGATE_DIR_BIN}"

  find "${SSHGATE_DIRECTORY}" -type d -exec chmod a=rx,u+w {} \;
  find "${SSHGATE_DIR_BIN}"   -type f -exec chmod a=r {} \;

  chmod a=rx "${SSHGATE_DIR_BIN}/sshgate-cli"
  chmod a=rx "${SSHGATE_DIR_TEST}/test.sh"

  find "${SSHGATE_DIR_USERS}"   -type f -name "*properties"     -exec chmod a=r,u+w {} \;
  find "${SSHGATE_DIR_TARGETS}" -type f -name "*properties"     -exec chmod a=r,u+w {} \;
  find "${SSHGATE_DIR_TARGETS}" -type f -name "ssh_logins.list" -exec chmod a=r,u+w {} \;
  find "${SSHGATE_DIR_TARGETS}" -type f -name "ssh_conf*"       -exec chmod a=r,u+w {} \;

  # sshkeys must be in 400
  find "${SSHGATE_DIR_USERS}"   -type f ! -name "*.properties" -exec chmod u=r {} \;
  find "${SSHGATE_DIR_TARGETS}" -name "${SSHGATE_TARGET_PRIVATE_SSHKEY_FILENAME}" -exec chmod a=,u+rw {} \;
  find "${SSHGATE_DIR_TARGETS}" -name "${SSHGATE_TARGET_PUBLIC_SSHKEY_FILENAME}"  -exec chmod a=r,u+w {} \;
  chmod a=,u+r "${SSHGATE_TARGET_DEFAULT_PRIVATE_SSHKEY_FILE}"
  chmod a=,u+r "${SSHGATE_TARGET_DEFAULT_PUBLIC_SSHKEY_FILE}"

OK

DOTHIS 'Install archive cron'
  mv "${SSHGATE_DIR_BIN}/archive-log.sh" /etc/cron.monthly/
  chmod +x /etc/cron.monthly/archive-log.sh
OK

if [ "${SSHGATE_USE_REMOTE_ADMIN_CLI}" = 'Y' -a "${action}" = 'install' ]; then
  DOTHIS 'configure /etc/sudoers'
    file="/tmp/sudoers.${RANDOM}"
    [ "${sudo_no_passwd}" = 'Y' ] && sudo_no_passwd='NOPASSWD:' || sudo_no_passwd=''
    grep -v "^${SSHGATE_GATE_ACCOUNT} " < /etc/sudoers > "${file}"
    mv "${file}" /etc/sudoers
    echo "${SSHGATE_GATE_ACCOUNT} ALL=(root) ${sudo_no_passwd}${SSHGATE_DIR_BIN}/sshgate-cli" >> /etc/sudoers
    chmod 0440 /etc/sudoers
    rm -f "${file}"
  OK
fi

BR

NOTICE "You may add ${SSHGATE_DIR_BIN} in your PATH variable"
BR

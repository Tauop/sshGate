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

. ./lib/message.lib.sh
. ./lib/ask.lib.sh
. ./lib/conf.lib.sh

# don't want to add exec.lib.sh in dependencies :/
user_id=`id -u`
[ "${user_id}" != "0" ] \
  && KO "You must execute $0 with root privileges"

CONF_SET_FILE "sshgate.conf"
CONF_LOAD

BR
MESSAGE "   --- sshGate server configuration ---"
MESSAGE "             by Patrick Guiran"
BR

ASK SSHGATE_DIR \
    "Where do you want to install sshGate [${SSHGATE_DIR}] ? " \
    "${SSHGATE_DIR}"
CONF_SAVE SSHGATE_DIR

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

BR
BR
DOTHIS 'Reload configuration'
  # reset loaded configuration and reload it
  __SSHGATE_CONF__=
  CONF_LOAD
OK

DOTHIS 'Installing sshGate'
  # create directories
  MK () { [ ! -d "$1/" ] && mkdir -p "$1"; }
  MK "${SSHGATE_DIR}"
  MK "${SSHGATE_DIR_CONF}"
  MK "${SSHGATE_DIR_BIN}"
  MK "${SSHGATE_DIR_USERS}"
  MK "${SSHGATE_DIR_TARGETS}"
  MK "${SSHGATE_DIR_USERS_GROUPS}"
  MK "${SSHGATE_DIR_LOG}"
  MK "${SSHGATE_DIR_ARCHIVE}"

  grep "${SSHGATE_GATE_ACCOUNT}" /etc/passwd >/dev/null 2>/dev/null
  if [ $? -ne 0 ]; then
    useradd "${SSHGATE_GATE_ACCOUNT}"
    home_dir=$( cat /etc/passwd | grep "${SSHGATE_GATE_ACCOUNT}" | cut -d':' -f6 )

    MK "${home_dir}"
    chmod 755 "${home_dir}"
    chown "${SSHGATE_GATE_ACCOUNT}" "${home_dir}"
  fi

  # install stuff
  cp $( find . -maxdepth 1 -type f ) "${SSHGATE_DIR_BIN}"

  mv "${SSHGATE_DIR_BIN}/sshgate.conf" "${SSHGATE_DIR_CONF}"
  find "${SSHGATE_DIR_BIN}" -name "CGU*.txt" -exec mv {} "${SSHGATE_DIR_CONF}" \;

  [ -d ./lib/ ] && cp -r ./lib/ "${SSHGATE_DIR_BIN}"

OK

DOTHIS 'Generate default sshkey pair'
  # generate targets default sshkey
  if [ ! -f "${SSHGATE_TARGET_DEFAULT_PRIVATE_SSHKEY_FILE}" ]; then
    ssh-keygen -t rsa -b 4096 -N '' -f "${SSHGATE_TARGET_DEFAULT_PRIVATE_SSHKEY_FILE}" >/dev/null
    mv "${SSHGATE_TARGET_DEFAULT_PRIVATE_SSHKEY_FILE}.pub" "${SSHGATE_TARGET_DEFAULT_PUBLIC_SSHKEY_FILE}"
  fi
OK

DOTHIS 'Setup files permissions'
  # permissions on files
  chown -R "${SSHGATE_GATE_ACCOUNT}" "${SSHGATE_DIR_LOG}"
  chown "${SSHGATE_GATE_ACCOUNT}" "${SSHGATE_DIR_USERS}"
  find "${SSHGATE_DIR}" -type d -exec chmod a+x {} \;
  find "${SSHGATE_DIR_BIN}" -type f -exec chmod a+r {} \;
  chown root "${SSHGATE_DIR_BIN}/sshgate"
  chmod a+x "${SSHGATE_DIR_BIN}/sshgate"

  # users properties file has to be readable for all unix users
  find "${SSHGATE_DIR_USERS}" -type f -name "*.properties" -exec chmod a+r {} \;

  # sshkeys must be in 400
  find "${SSHGATE_DIR_USERS}" -type f -exec chmod 400 {} \;
  find "${SSHGATE_DIR_TARGETS}" -name "${SSHGATE_TARGET_PRIVATE_SSHKEY_FILENAME}" -exec chmod 400 {} \;
  find "${SSHGATE_DIR_TARGETS}" -name "*properties" -exec chmod u+w {} \;

  # user properties files has to be ${SSHGATE_GATE_ACCOUNT} writable for CGU
  find "${SSHGATE_DIR_USERS}" -name "*.properties" -exec chown "${SSHGATE_GATE_ACCOUNT}" {} \;
  find "${SSHGATE_DIR_USERS}" -name "*.properties" -exec chmod u+w {} \;

  chmod 400 "${SSHGATE_TARGET_DEFAULT_PRIVATE_SSHKEY_FILE}"
  chmod 400 "${SSHGATE_TARGET_DEFAULT_PUBLIC_SSHKEY_FILE}"
  chown "${SSHGATE_GATE_ACCOUNT}" "${SSHGATE_TARGET_DEFAULT_PRIVATE_SSHKEY_FILE}"
  chown "${SSHGATE_GATE_ACCOUNT}" "${SSHGATE_TARGET_DEFAULT_PUBLIC_SSHKEY_FILE}"
OK

DOTHIS 'Update sshGate installation'
  # update files and replace patterns
  sed_repl=
  sed_repl="${sed_repl} s|^\( *\)# %% __SSHGATE_CONF__ %%.*$|\1. ${SSHGATE_DIR_CONF}/sshgate.conf|;"
  sed_repl="${sed_repl} s|^\( *\)# %% __SSHGATE_FUNC__ %%.*$|\1. ${SSHGATE_DIR_BIN}/sshgate.func|;"
  sed_repl="${sed_repl} s|^\( *\)# %% __CLI_HELP_SH__ %%.*$|\1. ${SSHGATE_DIR_BIN}/cli_help.sh|;"
  sed_repl="${sed_repl} s|^\( *\)# %% __LIB_MESSAGE__ %%.*$|\1. ${SSHGATE_DIR_BIN}/lib/message.lib.sh|;"
  sed_repl="${sed_repl} s|^\( *\)# %% __LIB_ASK__ %%.*$|\1. ${SSHGATE_DIR_BIN}/lib/ask.lib.sh|;"
  sed_repl="${sed_repl} s|^\( *\)# %% __LIB_CLI__ %%.*$|\1. ${SSHGATE_DIR_BIN}/lib/cli.lib.sh|;"
  sed_repl="${sed_repl} s|^\( *\)# %% __LIB_MAIL__ %%.*$|\1. ${SSHGATE_DIR_BIN}/lib/mail.lib.sh|;"
  sed_repl="${sed_repl} s|^\( *\)# %% __LIB_CONF__ %%.*$|\1. ${SSHGATE_DIR_BIN}/lib/conf.lib.sh|;"

  sed -i -e "${sed_repl}" "${SSHGATE_DIR_BIN}/sshgate"
  sed -i -e "${sed_repl}" "${SSHGATE_DIR_BIN}/sshgate.func"
  sed -i -e "${sed_repl}" "${SSHGATE_DIR_BIN}/sshgate.sh"
  sed -i -e "${sed_repl}" "${SSHGATE_DIR_BIN}/archive-log.sh"

  rm -f ${SSHGATE_DIR_BIN}/install.sh # ;-p
OK

DOTHIS 'Install archive cron'
  mv "${SSHGATE_DIR_BIN}/archive-log.sh" /etc/cron.monthly/
  chmod +x /etc/cron.monthly/archive-log.sh
OK

if [ "${SSHGATE_USE_REMOTE_ADMIN_CLI}" = 'Y' ]; then
  DOTHIS 'configure /etc/sudoers'
    file="/tmp/sudoers.${RANDOM}"
    [ "${sudo_no_passwd}" = 'Y' ] && sudo_no_passwd='NOPASSWD:' || sudo_no_passwd=''
    grep -v "^${SSHGATE_GATE_ACCOUNT} " < /etc/sudoers > "${file}"
    mv "${file}" /etc/sudoers
    echo "${SSHGATE_GATE_ACCOUNT} ALL=(root) ${sudo_no_passwd}${SSHGATE_DIR_BIN}/sshgate" >> /etc/sudoers
    chmod 0440 /etc/sudoers
    rm -f "${file}"
  OK
fi

BR

NOTICE "You may add ${SSHGATE_DIR_BIN} in your PATH variable"
BR

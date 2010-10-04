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

ASK SSHGATE_TARGETS_DEFAULT_USER \
    "What the default user account to use when connecting to target host [${SSHGATE_TARGETS_DEFAULT_USER}] ? " \
    "${SSHGATE_TARGETS_DEFAULT_USER}"
CONF_SAVE SSHGATE_TARGETS_DEFAULT_USER

ASK --yesno SSHGATE_MAIL_SEND \
    "Activate mail notification system [Yes] ?" \
    "Y"
[ "${SSHGATE_MAIL_SEND}" = 'N' ] && SSHGATE_MAIL_SEND='false'
if [ "${SSHGATE_MAIL_SEND}" = 'Y' ]; then
  SSHGATE_MAIL_SEND='true'
  ASK SSHGATE_MAIL_TO \
      "Who will receive mail notification (comma separated mails) ?" \
      "${SSHGATE_MAIL_TO}"
  [ -z "${SSHGATE_MAIL_TO}" ] && SSHGATE_MAIl_SEND='false'
else
  SSHGATE_MAIL_SEND='false'
fi
CONF_SAVE SSHGATE_MAIL_SEND
CONF_SAVE SSHGATE_MAIL_TO


BR
BR
DOTHIS 'Reload configuration'
  # reset loaded configuration and reload it
  __SSHGATE_CONF__=
  CONF_LOAD
OK

DOTHIS 'Installing sshGate'
  MK () { [ ! -d "$1/" ] && mkdir -p "$1"; }
  MK "${SSHGATE_DIR}"
  MK "${SSHGATE_DIR_CONF}"
  MK "${SSHGATE_DIR_BIN}"
  MK "${SSHGATE_DIR_USERS}"
  MK "${SSHGATE_DIR_TARGETS}"
  MK "${SSHGATE_DIR_USERS_GROUPS}"
  MK "${SSHGATE_DIR_TARGETS_GROUPS}"
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
  [ -d ./lib/ ] && cp -r ./lib/ "${SSHGATE_DIR_BIN}"

  # generate targets default sshkey
  if [ ! -f "${SSHGATE_TARGET_DEFAULT_PRIVATE_SSHKEY_FILE}" ]; then
    ssh-keygen -t rsa -b 4096 -N '' -f "${SSHGATE_TARGET_DEFAULT_PRIVATE_SSHKEY_FILE}" >/dev/null
    mv "${SSHGATE_TARGET_DEFAULT_PRIVATE_SSHKEY_FILE}.pub" "${SSHGATE_TARGET_DEFAULT_PUBLIC_SSHKEY_FILE}"
  fi

  # permissions on files
  chown "${SSHGATE_GATE_ACCOUNT}" "${SSHGATE_DIR_LOG}"
  find "${SSHGATE_DIR}" -type d -exec chmod -R a+x {} \;
  find "${SSHGATE_DIR_BIN}" -type f -exec chmod a+r {} \;
  chmod a+x "${SSHGATE_DIR_BIN}/sshgate"

  # sshkeys must be in 400
  find "${SSHGATE_DIR_USERS}" -type f -exec chmod 400 {} \;
  find "${SSHGATE_DIR_TARGETS}" -name "${SSHGATE_TARGET_PRIVATE_SSHKEY_FILENAME}" -exec chmod 400 {} \;

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
  sed_repl="${sed_repl} s|^\( *\)# %% __LIB_MESSAGE__ %%.*$|\1. ${SSHGATE_DIR_BIN}/lib/message.lib.sh|;"
  sed_repl="${sed_repl} s|^\( *\)# %% __LIB_ASK__ %%.*$|\1. ${SSHGATE_DIR_BIN}/lib/ask.lib.sh|;"
  sed_repl="${sed_repl} s|^\( *\)# %% __LIB_CLI__ %%.*$|\1. ${SSHGATE_DIR_BIN}/lib/cli.lib.sh|;"
  sed_repl="${sed_repl} s|^\( *\)# %% __LIB_MAIL__ %%.*$|\1. ${SSHGATE_DIR_BIN}/lib/mail.lib.sh|;"

  sed -i -e "${sed_repl}" "${SSHGATE_DIR_BIN}/sshgate"
  sed -i -e "${sed_repl}" "${SSHGATE_DIR_BIN}/sshgate.func"
  sed -i -e "${sed_repl}" "${SSHGATE_DIR_BIN}/sshgate.sh"
  sed -i -e "${sed_repl}" "${SSHGATE_DIR_BIN}/archive-log.sh"

  rm -f ${SSHGATE_DIR_BIN}/install.sh # ;-p
OK

DOTHIS 'Install archive cron'
  mv "${SSHGATE_DIR_BIN}/archive-log.sh" /etc/cron.weekly/
  chmod +x /etc/cron.weekly/archive-log.sh
OK
BR

NOTICE "You may add ${SSHGATE_DIR_BIN} in your PATH variable"
BR

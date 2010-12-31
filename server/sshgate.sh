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
# ----------------------------------------------------------------------------
# VARIABLES used
# - SSH_ORIGINAL_COMMAND : variable given by sshd, which contain the original
#                          ssh command.
# - SSHKEY_USER : the login of the connected user
# - SFTP_SERVER : contant which containt the path to the sftp-server binary
# - TARGET_HOST : target  host of the sshg call
# - TARGET_HOST_COMMAND : ssh command which will be exec on the ${TARGET_HOST}
# - TARGET_LOGIN : login to use when connecting to the ${TARGET_HOST}
# - TARGET_SSHKEY : ${TARGET_HOST} private ssh key
# - ORIGINAL_TARGET_HOST : copy of TARGET_HOST used by error messages
# - GLOG_FILE : Global ${TARGET_HOST} log file
# - SLOG_FILE : Session log file (one per session/user/host)
# - SSHGATE_LOG_FILE : Global sshGate log file
# ----------------------------------------------------------------------------

if [ $# -ne 1 ]; then
  echo "your SSH KEY is not well configured. Please contact the sshGate administrator."
  exit 1
fi

# GLOBAL configuration -------------------------------------------------------
SSHKEY_USER="$1"
SFTP_SERVER=/usr/libexec/openssh/sftp-server

# %% __SSHGATE_CONF__ %% <-- WARNING: don't remove. used by install.sh
# %% __SSHGATE_FUNC__ %% <-- WARNING: don't remove. used by install.sh

# one little function
mLOG () { local file=$1; shift; echo "$(date +'[%D %T]') $*" >> ${file}; }

if [ -z ${SSHKEY_USER:-} ]; then
  echo "your SSH key is not well configured. Please, contact the sshGate administrator."
  exit 1
fi

# determine action type (ssh or scp) and build TARGET_HOST -------------------
do_ssh='false'

if [ "${SSH_ORIGINAL_COMMAND}" != "${SSH_ORIGINAL_COMMAND#${SFTP_SERVER} }" \
  -o "${SSH_ORIGINAL_COMMAND}" != "${SSH_ORIGINAL_COMMAND#scp }" ]; then
  # SSH_ORIGNAL_COMMAND ends with the name of the target host
  TARGET_HOST=${SSH_ORIGINAL_COMMAND##* }

  if [ "${TARGET_HOST%%/*}" != "${TARGET_HOST}" ]; then
    SSH_ORIGINAL_COMMAND=${SSH_ORIGINAL_COMMAND%% ${TARGET_HOST}}
    target_files=${TARGET_HOST#*/}
    TARGET_HOST=${TARGET_HOST%%/*}
    if [ -z "${target_files}" -o "${target_files#/}" = "${target_files}" ]; then
      target_files="~/${target_files}"
    fi
    SSH_ORIGINAL_COMMAND="${SSH_ORIGINAL_COMMAND} ${target_files}"
  else
    SSH_ORIGINAL_COMMAND="${SSH_ORIGINAL_COMMAND%% ${TARGET_HOST}}"
    SSH_ORIGINAL_COMMAND="${SSH_ORIGINAL_COMMAND} ${TARGET_SCP_DIR}"
  fi
else
  # SSH_ORIGINAL_COMMAND starts with the name of the target host
  TARGET_HOST="${SSH_ORIGINAL_COMMAND%% *}"
  TARGET_HOST_COMMAND="${SSH_ORIGINAL_COMMAND##${TARGET_HOST}}"
  TARGET_HOST_COMMAND="${TARGET_HOST_COMMAND## }"
  do_ssh='true'
fi

# public commands ------------------------------------------------------------
if [ "${SSHGATE_ALLOW_REMOTE_COMMAND}" = 'Y' -a "${do_ssh}" = 'true' ]; then
  if [ "${TARGET_HOST}" = 'cmd' -o "${TARGET_HOST}" = 'cli' ]; then
    # inpired from ScriptHelper/cli.lib.sh
    # we don't want sshgate.sh to be dependant on ScriptHelper
    BUILD_SED_CODE () {
      local sed_cmd=
      for word in $( echo "$1" | tr ' ' $'\n' ); do
        [ "${word}" = '?' ] && word="\([^ ]*\)"
        sed_cmd="${sed_cmd} *${word}"
      done
      echo -n "s|^${sed_cmd} *$|$2|p; t;"
    }
    is_admin=$( USER_GET_CONF "${SSHKEY_USER}" IS_ADMIN )
    code=
    code="${code} $(BUILD_SED_CODE 'cmd list targets'   'USER_LIST_TARGETS')"
    code="${code} $(BUILD_SED_CODE 'cmd list targets ?' 'USER_LIST_TARGETS \1')"
    code="${code} $(BUILD_SED_CODE 'cmd sshkey all'     'DISPLAY_USER_SSHKEY_FILE all')"
    code="${code} $(BUILD_SED_CODE 'cmd sshkey ?'       'DISPLAY_USER_SSHKEY_FILE \1')"
    if [ "${SSHGATE_USE_REMOTE_ADMIN_CLI}" = 'Y' -a "${is_admin}" = 'true' ]; then
      code="${code} $(BUILD_SED_CODE 'cli' "sudo ${SSHGATE_DIR_BIN}/sshgate -u '${SSHKEY_USER}'")"
    fi
    code="${code} a \ echo 'ERROR: unknown command' "
    eval $(echo "${SSH_ORIGINAL_COMMAND}" | sed -n -e "$code" )
    exit 0;
  fi
fi

# check usage condition ------------------------------------------------------
if [ "${SSHGATE_USERS_MUST_ACCEPT_CGU}" = 'Y' -a -f "${SSHGATE_CGU_FILE}" ]; then
  has_accept_cgu=$( USER_GET_CONF "${SSHKEY_USER}" HAS_ACCEPT_CGU )
  if [ "${has_accept_cgu}" != 'true' ]; then
    cat "${SSHGATE_CGU_FILE}"
    echo
    retry=0
    while true ; do
      read -p "-> 'yes' / 'no' ? " var
      [ "${var}" = 'no' ] && exit 0;
      if [ "${var}" = 'yes' ]; then
        USER_SET_CONF "${SSHKEY_USER}" HAS_ACCEPT_CGU 'true'
        break;
      fi
      echo 'Invalid answer.'
      echo 'Type exactly "yes" or "no"'
      retry=$(( retry + 1 ))
      [ ${retry} -eq 3 ] && exit 1;
    done
  fi
fi


# If user don't specify a target host, ask for the target host ---------------

if [ -z "${TARGET_HOST}" ]; then
  echo "NOTICE: No target host given"
  read -p "Target host ? " TARGET_HOST
  TARGET_HOST=${TARGET_HOST%% *}
fi

# Determine information for connecting to the host ---------------------------
TARGET_LOGIN=$( GET_LOGIN "${TARGET_HOST}" )
TARGET_HOST=$( GET_HOST "${TARGET_HOST}" )

ORIGINAL_TARGET_HOST="${TARGET_HOST}"
TARGET_HOST=$( TARGET_REAL "${TARGET_HOST}" )
if [ -z "${TARGET_HOST}" ]; then
  echo "ERROR: Unknown host ${ORIGINAL_TARGET_HOST}."
  exit 1;
fi

GLOG_FILE=$( TARGET_LOG_FILE "${TARGET_HOST}" )
TARGET_SSHKEY=$( TARGET_PRIVATE_SSHKEY_FILE "${TARGET_HOST}" )
if [ -z "${TARGET_SSHKEY}" -o ! -r "${TARGET_SSHKEY:-}" ]; then
  echo "ERROR: can't read target host ssh key. Please contact the sshGate administrator"
  exit 1
fi

# check ACL ------------------------------------------------------------------
if [ $( HAS_ACCESS "${SSHKEY_USER}" "${TARGET_HOST}" "${TARGET_LOGIN}" ) = 'false' ]; then
  echo "ERROR: The '${ORIGINAL_TARGET_HOST}' doesn't exist or you don't have access to it (or with login '${TARGET_LOGIN}')"
  exit 1
fi

# Do the stuff ;-) -----------------------------------------------------------
mLOG ${GLOG_FILE} "New session $$. Connection from ${SSH_CONNECTION%% *} with SSH_ORIGINAL_COMMAND = ${SSH_ORIGINAL_COMMAND:-}"

if [ "${do_ssh:-}" = 'true' ]; then
  SLOG_FILE=$( TARGET_SESSION_LOG_FILE "${TARGET_HOST}" )
  mLOG ${GLOG_FILE} "Creating session log file ${SLOG_FILE}"
  mLOG ${SSHGATE_LOG_FILE} "[SSSH] ${SSHKEY_USER} -> ${TARGET_LOGIN}@${TARGET_HOST} ${TARGET_HOST_COMMAND}"

  TARGET_SSH_OPTIONS=$( TARGET_GET_SSH_OPTIONS "${TARGET_HOST}" )
  ssh -i ${TARGET_SSHKEY} ${TARGET_SSH_OPTIONS} ${TARGET_LOGIN}@${TARGET_HOST} "${TARGET_HOST_COMMAND}" | tee ${SLOG_FILE}
  mLOG ${GLOG_FILE} "Session $$ ended. logfile = ${SLOG_FILE}"
else
  mLOG ${SSHGATE_LOG_FILE} "[SCP] ${SSHKEY_USER} -> ${TARGET_LOGIN}@${TARGET_HOST} ${SSH_ORIGINAL_COMMAND}"

  TARGET_SCP_OPTIONS=$( TARGET_GET_SCP_OPTIONS "${TARGET_HOST}" )
  ssh -i ${TARGET_SSHKEY} ${TARGET_SCP_OPTIONS} ${TARGET_LOGIN}@${TARGET_HOST} "${SSH_ORIGINAL_COMMAND}"
  mLOG ${GLOG_FILE} "Transfert $$ completed."
fi

exit ${RETURN_VALUE}

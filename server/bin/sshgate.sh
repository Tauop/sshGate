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
# - ORIGINAL_TARGET_HOST : copy of TARGET_HOST used by error messages
# ----------------------------------------------------------------------------

if [ $# -ne 1 -o -z "${1:-}" ]; then
  echo "your SSH KEY is not well configured. Please contact the sshGate administrator."
  exit 1
fi

# GLOBAL configuration -------------------------------------------------------
SSHKEY_USER="$1"

# Load libraries -------------------------------------------------------------
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

load SSHGATE_DIRECTORY       '/etc/sshgate.conf'
load SCRIPT_HELPER_DIRECTORY '/etc/scripthealper.conf'

load __SSHGATE_SETUP__ "${SSHGATE_DIRECTORY}/data/sshgate.setup"
load __SSHGATE_CORE__  "${SSHGATE_DIR_CORE}/sshgate.core"
load __LIB_ASK__       "${SCRIPT_HELPER_DIRECTORY}/ask.lib.sh"
load __LIB_RECORD__    "${SCRIPT_HELPER_DIRECTORY}/record.lib.sh"

# one little function --------------------------------------------------------
mLOG () { local file=$1; shift; echo "$(date +'[%D %T]') $*" >> ${file}; }

# determine action type (ssh or scp) and build TARGET_HOST -------------------
if [ "${SSH_ORIGINAL_COMMAND}" != "${SSH_ORIGINAL_COMMAND#/usr/libexec/openssh/sftp-server }" \
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
  action_type='scp'
else
  # SSH_ORIGINAL_COMMAND starts with the name of the target host
  TARGET_HOST="${SSH_ORIGINAL_COMMAND%% *}"
  TARGET_HOST_COMMAND="${SSH_ORIGINAL_COMMAND##${TARGET_HOST}}"
  TARGET_HOST_COMMAND="${TARGET_HOST_COMMAND## }"
  action_type='ssh'
fi

# public commands ------------------------------------------------------------
if [ "${SSHGATE_ALLOW_REMOTE_COMMAND}" = 'Y' -a "${action_type}" = 'ssh' ]; then
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
    code="${code} $(BUILD_SED_CODE 'cmd list targets'    'USER_LIST_TARGETS ${SSHKEY_USER}' )"
    code="${code} $(BUILD_SED_CODE 'cmd list targets ?'  'USER_LIST_TARGETS \1'             )"
    code="${code} $(BUILD_SED_CODE 'cmd user sshkey ?'   'USER_SSHKEY_DISPLAY \1'           )"
    code="${code} $(BUILD_SED_CODE 'cmd target sshkey ?' 'TARGET_SSHKEY_DISPLAY \1'         )"
    if [ "${SSHGATE_USE_REMOTE_ADMIN_CLI}" = 'Y' -a "${is_admin}" = 'true' ]; then
      code="${code} $(BUILD_SED_CODE 'cli' "sudo ${SSHGATE_DIR_BIN}/sshgate-cli -u '${SSHKEY_USER}'")"
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
    ASK --yesno var "-> 'yes' / 'no' ?"
    [ "${var}" = 'N' ] && exit 1;
    USER_SET_CONF "${SSHKEY_USER}" HAS_ACCEPT_CGU 'true'
  fi
fi


# If user don't specify a target host, ask for the target host ---------------
if [ -z "${TARGET_HOST}" ]; then
  echo "NOTICE: No target host given"
  read -p "Target host ? " TARGET_HOST
  TARGET_HOST=${TARGET_HOST%% *}
fi

# Determine information for connecting to the host ---------------------------
ORIGINAL_TARGET_HOST="${TARGET_HOST}"
TARGET_LOGIN=$( GET_LOGIN "${TARGET_HOST}" )
TARGET_HOST=$( GET_HOST "${TARGET_HOST}" )

TARGET_HOST=$( TARGET_REAL "${TARGET_HOST}" )
if [ -z "${TARGET_HOST}" ]; then
  echo "ERROR: Unknown host ${ORIGINAL_TARGET_HOST}."
  exit 1;
fi

# check ACL ------------------------------------------------------------------
if [ $( HAS_ACCESS "${SSHKEY_USER}" "${ORIGINAL_TARGET_HOST}" ) = 'false' ]; then
  echo "ERROR: The '${ORIGINAL_TARGET_HOST}' doesn't exist or you don't have access to it (or with login '${TARGET_LOGIN}')"
  exit 1
fi

# Do the stuff ;-) -----------------------------------------------------------
SESSION_START "$$" "${SSHKEY_USER}" "${TARGET_HOST}" "${action_type}"

if [ "${action_type:-}" = 'ssh' ]; then
  SESSION_RECORD_FILE=$( SESSION_TARGET_GET_RECORD_FILE "${SSHKEY_USER}" "${TARGET_HOST}" )
  SSH_CONFIG_FILE=$( TARGET_SSH_GET_CONFIG "${TARGET_HOST}" "${TARGET_LOGIN}" )

  RECORD --file "${SESSION_RECORD_FILE}" "ssh -F '${SSH_CONFIG_FILE}' ${TARGET_HOST} '${TARGET_HOST_COMMAND}'"
  RETURN_VALUE=$?
  rm -f "${SSH_CONFIG_FILE}"
else
  SSH_CONFIG_FILE=$( TARGET_SSH_GET_CONFIG "${TARGET_HOST}" "${TARGET_LOGIN}" )

  ssh -F "${SSH_CONFIG_FILE}" ${TARGET_HOST} "${SSH_ORIGINAL_COMMAND}"
  RETURN_VALUE=$?
  rm -f "${SSH_CONFIG_FILE}"
fi

SESSION_END "$$" "${SSHKEY_USER}" "${TARGET_HOST}" "${SESSION_RECORD_FILE:-}"

exit ${RETURN_VALUE}

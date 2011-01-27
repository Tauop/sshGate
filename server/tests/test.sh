#!/bin/bash
#
# Copyright (c) 2010 Linagora
# Patrick Guiran <pguiran@linagora.com>
# http://github.com/Tauop/ScriptHelper
#
# ScriptHelper is free software, you can redistribute it and/or modify
# it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License, or (at your option) any later version.
#
# ScriptHelper is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

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

load SSHGATE_DIRECTORY '/etc/sshgate.conf'
load __SSHGATE_SETUP__ "${SSHGATE_DIRECTORY}/data/sshgate.setup"


testcases=$( find "${SSHGATE_DIR_BIN}/tests/" -type f -iname "*.testcase" -printf "%P\n" \
             | sed -e 's/^\(.*\)[.]testcase$/\1/' )

usage () {
  testcases=$( echo -n "${testcases}" | tr $'\n' ',' | sed -e 's/,/, /g' )
  echo 'Usage: $0 <test-case>'
  echo "    <test-case> : ${testcases}" | fold
  exit 1
}

if [ $# -ne 1 ]; then
 echo 'ERROR: Bad arguments'
  usage
fi

TEST_CASE="$1"
TEST_CASE_DIR="${SSHGATE_DIR_BIN}/tests"

if [ "${TEST_CASE}" != 'all' ]; then
  TEST_CASE="${TEST_CASE_DIR}/${TEST_CASE}.testcase"

  if [ ! -r "${TEST_CASE}" ]; then
    echo 'ERROR: unknown test-case'
    usage
  fi
fi

# don't use function.lib.sh functions !
mDOTHIS() { echo -n "- $* ... "; }
mOK()     { echo 'OK';           }

# tell sshGate module we are making tests :-)
SSHGATE_TEST='sshGateTest'

# --------------------------------------------------------------------------
mDOTHIS 'Loading sshGate core'
  load __SSHGATE_CLI__   "${SSHGATE_DIR_BIN}/sshgate-cli"
  load __LIB_RANDOM__    "${SCRIPT_HELPER_DIRECTORY}/random.lib.sh"
mOK

# --------------------------------------------------------------------------
mDOTHIS 'Setup sshGate data directory'
  # get from sshgate.conf
  SSHGATE_DIRECTORY="/tmp/sshgate.$(RANDOM)"
  SSHGATE_DIR_DATA="${SSHGATE_DIRECTORY}/data"
  SSHGATE_DIR_BIN="${SSHGATE_DIRECTORY}/bin"
  SSHGATE_DIR_CORE="${SSHGATE_DIRECTORY}/core"
  SSHGATE_DIR_USERS="${SSHGATE_DIRECTORY}/users"
  SSHGATE_DIR_TARGETS="${SSHGATE_DIRECTORY}/targets"
  SSHGATE_DIR_USERS_GROUPS="${SSHGATE_DIRECTORY}/users.groups"
  SSHGATE_DIR_LOG="${SSHGATE_DIRECTORY}/log"
  SSHGATE_DIR_ARCHIVE="${SSHGATE_DIRECTORY}/archives"
  SSHGATE_LOG_FILE="${SSHGATE_DIR_LOG}/sshgate.log"

  # get from install.sh
  MK () { [ ! -d "$1/" ] && mkdir -p "$1"; }
  MK "${SSHGATE_DIRECTORY}"
  MK "${SSHGATE_DIR_DATA}"
  MK "${SSHGATE_DIR_BIN}"
  MK "${SSHGATE_DIR_CORE}"
  MK "${SSHGATE_DIR_USERS}"
  MK "${SSHGATE_DIR_TARGETS}"
  MK "${SSHGATE_DIR_USERS_GROUPS}"
  MK "${SSHGATE_DIR_LOG}"
  MK "${SSHGATE_DIR_ARCHIVE}"
mOK

# --------------------------------------------------------------------------
mDOTHIS 'Generate temporary test file'
  input_test_file="/tmp/test_sshgate_input.$(RANDOM)"
  output_test_file="/tmp/test_sshgate_output.$(RANDOM)"
  expected_test_file="/tmp/test_sshgate_expected.$(RANDOM)"
  sshkey_priv_test_file="/tmp/test_sshgate_sshkey.$(RANDOM)"
  sshkey_pub_test_file="${sshkey_priv_test_file}.pub"
  sshkey_priv_unix_test_file="/tmp/test_sshgate_sshkey_unix.$(RANDOM)"
  sshkey_pub_unix_test_file="${sshkey_priv_unix_test_file}.pub"
mOK

# --------------------------------------------------------------------------
mDOTHIS 'Generate temporary sshkey test file'
  # generate fake ssh keys pair without passphrase
  ssh-keygen -t rsa -b 1024 -N '' -f "${sshkey_priv_test_file}"      >/dev/null
  ssh-keygen -t rsa -b 1024 -N '' -f "${sshkey_priv_unix_test_file}" >/dev/null
  chmod 400 "${sshkey_priv_test_file}"
  chmod 400 "${sshkey_priv_unix_test_file}"
mOK

# --------------------------------------------------------------------------
mDOTHIS 'Create and setup temporary Unix account'
  sshgate_unix_test_account="sshgate$(RANDOM)"
  useradd --home "/home/${sshgate_unix_test_account}" "${sshgate_unix_test_account}"
  mkdir -p "/home/${sshgate_unix_test_account}/.ssh/"
  cp "${sshkey_pub_unix_test_file}" "/home/${sshgate_unix_test_account}/.ssh/authorized_keys2"
  chown -R "${sshgate_unix_test_account}" "/home/${sshgate_unix_test_account}"

  user_unix_test_account="user$(RANDOM)"
  useradd --home "/home/${user_unix_test_account}" "${user_unix_test_account}"
  mkdir -p "/home/${user_unix_test_account}/.ssh/"
  cp "${sshkey_pub_unix_test_file}" "/home/${user_unix_test_account}/.ssh/authorized_keys2"
  chown -R "${user_unix_test_account}" "/home/${user_unix_test_account}"

  # change sshGate settings
  SSHGATE_GATE_ACCOUNT="${sshgate_unix_test_account}"
  SSHGATE_TARGETS_DEFAULT_SSH_LOGIN="${user_unix_test_account}"

  # need to read lines prefixed by "<<-" from ${expected_test_file}/${input_test_file}.
  # it ends when ASK read '->>' string
  SSHGATE_EDITOR='input="";
                  while [ "${input}" != "->>" ]; do
                    ASK --no-print --no-echo --allow-empty input
                    input="${input#"<<-"}"
                    if [ "${input}" != "${input#"<<="}" ]; then
                      echo "${input#"<<="}"; break;
                    fi
                    [ "${input}" != "->>" ] && echo "${input}"
                  done >>'

  # install unix user sshkey to sshGate default key so that we can call TARGET_ADD
  # and TARGET_SSH_INSTALL_KEY without problems
  SSHGATE_TARGET_DEFAULT_PRIVATE_SSHKEY_FILE="${SSHGATE_DIR_DATA}/${SSHGATE_TARGET_PRIVATE_SSHKEY_FILENAME}"
  SSHGATE_TARGET_DEFAULT_PUBLIC_SSHKEY_FILE="${SSHGATE_DIR_DATA}/${SSHGATE_TARGET_PUBLIC_SSHKEY_FILENAME}"
  cp "${sshkey_priv_unix_test_file}" "${SSHGATE_TARGET_DEFAULT_PRIVATE_SSHKEY_FILE}"
  cp "${sshkey_pub_unix_test_file}"  "${SSHGATE_TARGET_DEFAULT_PUBLIC_SSHKEY_FILE}"
mOK


# --------------------------------------------------------------------------

if [ "${TEST_CASE}" != 'all' ]; then
  # Load the test-case
  . "${TEST_CASE}"
else
  for test in ${testcases}; do
    mDOTHIS 'Reset temporary test file'
      echo -n '' > "${input_test_file}"
      echo -n '' > "${output_test_file}"
      echo -n '' > "${expected_test_file}"
    mOK
    mDOTHIS 'Reset sshGate data directories'
      rm -rf "${SSHGATE_DIRECTORY}"
      MK "${SSHGATE_DIRECTORY}"
      MK "${SSHGATE_DIR_DATA}"
      MK "${SSHGATE_DIR_BIN}"
      MK "${SSHGATE_DIR_CORE}"
      MK "${SSHGATE_DIR_USERS}"
      MK "${SSHGATE_DIR_TARGETS}"
      MK "${SSHGATE_DIR_USERS_GROUPS}"
      MK "${SSHGATE_DIR_LOG}"
      MK "${SSHGATE_DIR_ARCHIVE}"
      cp "${sshkey_priv_unix_test_file}" "${SSHGATE_TARGET_DEFAULT_PRIVATE_SSHKEY_FILE}"
      cp "${sshkey_pub_unix_test_file}"  "${SSHGATE_TARGET_DEFAULT_PUBLIC_SSHKEY_FILE}"
    mOK
    TEST_CASE="${TEST_CASE_DIR}/${test}.testcase"
    . "${TEST_CASE}"
  done
fi

# --------------------------------------------------------------------------
mDOTHIS 'Remove tests data'
  userdel "${sshgate_unix_test_account}"
  userdel "${user_unix_test_account}"
  [ -d "/home/${sshgate_unix_test_account}/" ] && rm -rf "/home/${sshgate_unix_test_account}"
  [ -d "/home/${user_unix_test_account}/"    ] && rm -rf "/home/${user_unix_test_account}"

  mail_test_file=$( MAIL_GET_FILE )
  rm -f "${input_test_file}" "${output_test_file}" "${expected_test_file}"
  rm -f "${sshkey_priv_test_file}" "${sshkey_pub_test_file}"
  rm -f "${sshkey_priv_unix_test_file}" "${sshkey_pub_unix_test_file}"
  rm -f "${mail_test_file}"
  rm -rf "${SSHGATE_DIRECTORY}"
mOK
exit 0

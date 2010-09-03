#!/bin/bash
#
# Copyright (c) 2010 Linagora
# Patrick Guiran <guiran@linagora.com>
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

SSH_CLIENT_DIR=~/.ssh
SSH_CLIENT_CONFIG=~/.ssh/config
SSHGATE_GATE_ACCOUNT='sshgate'

# include ask.lib.sh from ScriptHelper project (http://github.com/Tauop/ScriptHelper)
. ./lib/message.lib.sh
. ./lib/ask.lib.sh

echo
echo "  --- sshGate client configuration ---"
echo "         by Patrick Guiran"
echo
echo "This script will help you to configure your ssh client in order to use sshGate."
echo

sshgate_user=
sshgate_host=
sshgate_sshkey=

ASK sshgate_host    "What is the sshgGate hostname or IP address?"
ASK sshgate_user    "What is the username to use when connecting to sshGate? [${SSHGATE_GATE_ACCOUNT}]" "${SSHGATE_GATE_ACCOUNT}"
ASK sshgate_sshkey  "What is the SSH private key file to use for sshGate? [${SSH_CLIENT_DIR}/id_rsa]" "${SSH_CLIENT_DIR}/id_rsa"

[ ! -d ${SSH_CLIENT_DIR} ] && mkdir -p ${SSH_CLIENT_DIR}

ssh_config="
Host sshgate
  User ${sshgate_user}
  IdentityFile ${sshgate_sshkey}
  HostName ${sshgate_host}
  ControlMaster auto
  ControlPath /tmp/%r@%h:%p"

echo                 >> ${SSH_CLIENT_CONFIG}
echo "${ssh_config}" >> ${SSH_CLIENT_CONFIG}
echo                 >> ${SSH_CLIENT_CONFIG}


echo
echo "The 'sshgate' host has been configured in your ssh configuration file ${SSH_CLIENT_CONFIG}"
echo
echo "You can use the 'sshg' and 'scpg' commands as equivalents of 'ssh' and 'scp' commands through sshGate"
echo "Just copy the 'sshg' and 'scpg' files into a directory which is in your PATH (eg.: /usr/local/bin/),"
echo "and make sure they are chmod a+rx."
echo "If you don't want to use the 'sshg' and 'scpg' commands, please read the README file to use sshGate directly."
echo

exit 0

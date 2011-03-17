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

if [ $# -eq 1 ]; then
  month_ago="$1"
fi

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


load SSHGATE_DIRECTORY       '/etc/sshgate.conf'
load SCRIPT_HELPER_DIRECTORY '/etc/ScriptHelper.conf'

load __SSHGATE_SETUP__       "${SSHGATE_DIRECTORY}/data/sshgate.setup"
load __LIB_RANDOM__          "${SCRIPT_HELPER_DIRECTORY}/random.lib.sh"

archive="${SSHGATE_DIR_ARCHIVE}/$( date +%Y%m --date "-${month_ago} month" )_log.tar"
tmp_file="/tmp/files.$(RANDOM)"

find "${SSHGATE_DIR_LOGS_TARGETS}" -name "$( date +%Y%m --date "-${month_ago} month" )*" >  "${tmp_file}"
find "${SSHGATE_DIR_LOGS_TARGETS}" -name 'global.log'                                    >> "${tmp_file}"

tar cf "${archive}" "${SSHGATE_DIR_LOGS}/sshgate.log"
cat "${tmp_file}" | xargs tar rf "${archive}"
gzip "${archive}"

#cat "${tmp_file}" | xargs rm -f
#rm -f "${SSHGATE_DIR_LOGS}/sshgate.log"
rm -f "${tmp_file}"

exit 0;

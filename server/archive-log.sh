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

# %% __SSHGATE_CONF__ %% <-- WARNING: don't remove. used by install.sh

archive="${SSHGATE_DIR_ARCHIVE}/$( date +%Y%m --date '-1 month' )_log.tar"
tmp_file="/tmp/files.${RANDOM}"

find "${SSHGATE_DIR_LOG}" -name "$( date +%Y%m --date '-1 month' )*" >  "${tmp_file}"
find "${SSHGATE_DIR_LOG}" -name 'global.log'                         >> "${tmp_file}"

tar cf "${archive}" "${SSHGATE_DIR_LOG}/sshgate.log"
cat "${tmp_file}" | xargs tar rf "${archive}"
gzip "${archive}"

cat "${tmp_file}" | xargs rm -f
rm -f "${SSHGATE_DIR_LOG}/sshgate.log"
rm -f "${tmp_file}"

exit 0;

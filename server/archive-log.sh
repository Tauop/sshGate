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

find_opt=
find_opt=" -name '$( date +%Y%m%d --date '-14 day' )' "
for d in `seq 13 -1 7`; do
  find_opt=" -o -name '$( date +%Y%m%d --date '-$d day' )' "
done

files=$( eval "find '${SSHGATE_DIR_LOG}' ${find_opt} " )
archive="${SSHGATE_DIR_ARCHIVE}/$( date +%Y%m%d --date '-14 day' )-$( date +%Y%m%d --date '-$d day' )_log.tar.gz"

tar zcvf "${archive}" ${files} >/dev/null
echo "rm -f ${files}"

return 0;

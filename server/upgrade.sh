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
# ----------------------------------------------------------------------------
# List of migrations
#  old   -> new   | migration name
#   0    -> x     | UPDATE_ACCESS_FILENAMES
#   0    -> x     | ADD_DEFAULT_LOGIN_TO_TARGET_LOGINS_LIST
#   0    -> x     | REMOVE_DISABLED_TARGET_VARIABLES
#   <0.2 -> >=0.2 | UPGRADE_LOGS_ARCHITECTURE
# ----------------------------------------------------------------------------
# Compatibility break between version
# * 0.1 -> 0.2 : Log format has changed. before, logs were made with 'tee'
#                whereas in 0.2 version, they are created with script and can
#                be replayed with scriptreplay. (integration of record.lib.sh)
# ----------------------------------------------------------------------------

# migrations allow sshGate to migration from an old to a newer version
GET_MIGRATIONS() {
  local old_version="$1" new_version="$2" migrations=

  # no migration needed when version are the same
  [ "${old_version}" = "${new_version}" ] && return 0;

  if [ "${old_version}" = '0' ]; then
    migrations="${migrations} UPDATE_ACCESS_FILENAMES"
    migrations="${migrations} ADD_DEFAULT_LOGIN_TO_TARGET_LOGINS_LIST"
    migrations="${migrations} REMOVE_DISABLED_TARGET_VARIABLES"
    migrations="${migrations} MOVE_CONF_TO_DATA"
  fi

  # here, we break compatibility between 0.1 and 0.2 :-/
  if [    "$( expr "${old_version}" '<'  '0.2' )" = '1' \
       -a "$( expr "${new_version}" '>=' '0.2' )" = '1' ]; then
    migrations="${migrations} UPGRADE_LOGS_ARCHITECTURE"
  fi

  echo "${migrations}"
  return 0;
}

# - 0.0 -> x -----------------------------------------------------------------

UPDATE_ACCESS_FILENAMES () {
  find "${SSHGATE_DIR_TARGETS}"                       \
      -name "${SSHGATE_TARGETS_USER_ACCESS_FILENAME}" \
      -exec mv "{}" "{}.${SSHGATE_TARGETS_DEFAULT_SSH_LOGIN}" \;

  find "${SSHGATE_DIR_TARGETS}"                            \
      -name "${SSHGATE_TARGETS_USERGROUP_ACCESS_FILENAME}" \
      -exec mv "{}" "{}.${SSHGATE_TARGETS_DEFAULT_SSH_LOGIN}" \;
  return 0;
}

ADD_DEFAULT_LOGIN_TO_TARGET_LOGINS_LIST () {
  local target=
  for target in $( find "${SSHGATE_DIR_TARGETS}" -mindepth 1 -type d ); do
    echo "${SSHGATE_TARGETS_DEFAULT_SSH_LOGIN}" >> "${target}/${SSHGATE_TARGETS_SSH_LOGINS_FILENAME}"
  done
  return 0;
}

# remove unused configuration variable from target configuaration file
#  - SSH_PORT
#  - SCP_PORT
#  - SSH_ENABLE_X11
REMOVE_DISABLED_TARGET_VARIABLES () {
  local target= tmp_file=

  # need random !
  [ "${__LIB_RANDOM__:-}" != 'Loaded' ] && . ./lib/random.lib.sh
  tmp_file="/tmp/properties.$( RANDOM )"

  for target in $( find "${SSHGATE_DIR_TARGETS}" -mindepth 1 -type d ); do
    [ ! -f "${target}/properties" ] && continue
    grep -v -E '^(SSH_PORT|SCP_PORT|SSH_ENABLE_X11)=' \
       < "${target}/properties" > "${tmp_file}"
    mv "${tmp_file}" "${target}/properties"
  done
  return 0;
}

MOVE_CONF_TO_DATA () {
  mv "${SSHGATE_DIRECTORY}/conf" "${SSHGATE_DIRECTORY}/data"
}

# - <0.2 -> >=0.2 ------------------------------------------------------------

# log/ directory will be renaned/moved. Besides, logs directory architecture
# and logs format changed. So we have to archive all present logs.
# now we create logs/targets-logs/ for targets logs and logs/users-logs/ for users logs
UPGRADE_LOGS_ARCHITECTURE () {
  local reply=

  BR; BR
  MSG "Upgrading to 0.2 breaks some compatibilities with logs, whom format has changed."
  ASK --yes-no reply "Do you want to processed the upgrade and archive all existing logs [y/N] ?" 'N'

  [ "${reply}" = 'N' ] && exit 1

  # make backups of all logs
  mkdir -p "${SSHGATE_DIRECTORY}/backup/"
  tar zcvf "${SSHGATE_DIRECTORY}/backup/sshGate-logs_before-`date +%Y%m%d`.tar.gz" \
           "${SSHGATE_DIRECTORY}/log/" >/dev/null 2>/dev/null
  mv "${SSHGATE_DIRECTORY}/archives/" "${SSHGATE_DIRECTORY}/backup/"

  NOTICE "Old logs are in '${SSHGATE_DIRECTORY}/backup/'."

  # create directories
  mkdir -p "${SSHGATE_DIRECTORY}/archives/"
  mkdir -p "${SSHGATE_DIRECTORY}/logs/"
  mkdir -p "${SSHGATE_DIRECTORY}/logs/users-logs/"
  mkdir -p "${SSHGATE_DIRECTORY}/logs/targets-logs/"

  # finish to create directory structure
  for target in $( ls "${SSHGATE_DIRECTORY}/log/" ); do
    mkdir -p "${SSHGATE_DIRECTORY}/logs/targets-logs/${target}"
  done
  rm -rf "${SSHGATE_DIRECTORY}/log/"

  chown -R "${SSHGATE_GATE_ACCOUNT}" "${SSHGATE_DIRECTORY}/logs/"

  return 0;
}

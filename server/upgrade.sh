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
# old -> new | migration name
#   0 -> x   | UPDATE_ACCESS_FILENAMES
#   0 -> x   | ADD_DEFAULT_LOGIN_TO_TARGET_LOGINS_LIST
#   0 -> x   | REMOVE_DISABLED_TARGET_VARIABLES
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
  fi

  echo "${migrations}"
  return 0;
}

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


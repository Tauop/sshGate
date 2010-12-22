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

private_SHOW_HELP_USERS () {
  MSG_INDENT_INC
    MESSAGE "user list                                 - List all users"
    MESSAGE "user add <username> key <sshkey-file>     - add a new user"
    MESSAGE "user del <username>                       - delete a user"
    MESSAGE "user <username> display conf              - display user configuration"
    MESSAGE "user <username> set conf <var> <value>    - set a variable in user configuration"
    MESSAGE "user <username> list groups               - list group of user"
    MESSAGE "user <username> list targets              - list targets hosts of user"
    MESSAGE "user <username> has access <target-name>  - tell if a user has access to a target host"
    MESSAGE "user <username> access info               - list all target user has access to, and how"
    MESSAGE "user <username> access notify             - notify the user about its access list (via mail)"
  MSG_INDENT_DEC
  return 0
}

private_SHOW_HELP_USER_CONF () {
  MSG_INDENT_INC
    MESSAGE "List of all variables of a user configuration."
    MESSAGE "See 'help users' for user's configuration commands"
    BR
    MESSAGE "IS_ADMIN      - Tell is a user is a sshGate administrator (boolean [true|false], default: false)"
    MESSAGE "IS_RESTRICTED - Tell if user's access is controled by ACL (boolean [true|false], default: true)"
    MESSAGE "MAIL          - user's E-mail (string, default: <empty>)"
  MSG_INDENT_DEC
}

private_SHOW_HELP_USERGROUPS () {
  MSG_INDENT_INC
    MESSAGE "usergroup list                              - list all users groups"
    MESSAGE "usergroup add <group-name>                  - create a users group"
    MESSAGE "usergroup del <group-name>                  - delete a users group"
    MESSAGE "usergroup <group-name> list users           - list users of a group"
    MESSAGE "usergroup <group-name> add user <username>  - add an user into a group"
    MESSAGE "usergroup <group-name> del user <username>  - delete an user from a group"
    MESSAGE "usergroup <group-name> list targets         - list targets which usergroup has access to"
  MSG_INDENT_DEC
  return 0
}

private_SHOW_HELP_TARGETS () {
  MSG_INDENT_INC
    MESSAGE "target list [<pattern>]                      - list all targets, whose name match <pattern> if given"
    MESSAGE "target add <target-name>                     - add a new target host, and generate a private sshkey"
    MESSAGE "target add <target-name> key <sshkey-file>   - add a new target host, with a given private sshkey"
    MESSAGE "target del <target-name>                     - delete a target host"
    MESSAGE "target alias list                            - list all aliases of a target host"
    MESSAGE "target alias del <alias-name>                - delete an alias name"
    MESSAGE "target ssh test all                          - test to ssh connectivity for all targets"
    MESSAGE "target ssh install all keys                  - install public sshkey on all targets"
    MESSAGE "target <target-name> display conf            - display target configuration file"
    MESSAGE "target <target-name> set conf <var> <value>  - set a variable in the target configuration file"
    MESSAGE "target <target-name> realname                - print the real name of a target host"
    MESSAGE "target <target-name> add alias <alias-name>  - add an alias of target hostname"
    MESSAGE "target <target-name> del alias <alias-name>  - delete an alias of the target"
    MESSAGE "target <target-name> list aliases            - list aliases of the target host"
    MESSAGE "target <target-name> access info             - list all user who has access to target, and how"
    MESSAGE "target <target-name> ssh test                - test ssh connectivity for the target host"
    MESSAGE "target <target-name> ssh install key          - install sshkey on the target host"
  MSG_INDENT_DEC
  return 0
}

private_SHOW_HELP_TARGET_CONF () {
  MSG_INDENT_INC
    MESSAGE "List of all variables of a target configuration"
    MESSAGE "See 'help targets' for target's configuration commands"
    BR
    MESSAGE "SSH_PORT       - TCP port to use when connecting with ssh to the target"
    MESSAGE "SSH_ENABLE_X11 - Enable X11 forwarding when connecting with ssh to the target"
    MESSAGE "SCP_PORT       - TCP port to use when connecting for scp-ing file to/from the target"
  MSG_INDENT_DEC
  return 0
}

private_SHOW_HELP_TARGET_ACCESS () {
  MSG_INDENT_INC
    MESSAGE "target <target-name> access list users                  - list all users who can access to the target host"
    MESSAGE "target <target-name> access add user <user-name>        - give user access to a target host"
    MESSAGE "target <target-name> access del user <user-name>        - revoke user access of target host"
    MESSAGE "target <target-name> access list usergroups             - list all groups who can access to the target host"
    MESSAGE "target <target-name> access add usergroup <group-name>  - give group access to a target host"
    MESSAGE "target <target-name> access del usergroup <group-name>  - revoke group access of a target host"
  MSG_INDENT_DEC
  return 0
}

private_SHOW_HELP_MISC () {
  MSG_INDENT_INC
    MESSAGE "build authorized_keys - force re-write of sshgate account ./ssh/authorized_keys file"
    MESSAGE "build known_hosts     - force re-write of sshgate account ./ssh/knonwn_hosts file"
    MESSAGE "quit                  - exit the current CLI context menu, or exit the CLI"
    MESSAGE "exit                  - exit the CLI"
  MSG_INDENT_DEC
  return 0
}

private_SHOW_HELP_ALL () {
  MSG_INDENT_INC
    MSG "= Users ="
    private_SHOW_HELP_USERS
    BR
    MSG "= User's Group ="
    private_SHOW_HELP_USERGROUPS
    BR
    MSG "= Target ="
    private_SHOW_HELP_TARGETS
    BR
    MSG "= Target's Access ="
    private_SHOW_HELP_TARGET_ACCESS
    BR
    MSG "= Misc ="
    private_SHOW_HELP_MISC
    BR
  MSG_INDENT_DEC
  return 0
}

SHOW_HELP () {
  if [ $# -eq 0 ]; then
    MSG_INDENT_INC
      MESSAGE "Help has severals sections. To have list of command of a section, use help <section> command."
      BR
      MESSAGE "  all         - Show all commands"
      MESSAGE "  user        - Users related commands"
      MESSAGE "  user conf   - User configuration variable"
      MESSAGE "  usergroup   - Users' groups related commands"
      MESSAGE "  target      - Targets related commands"
      MESSAGE "  target conf - Target configuration variable"
      MESSAGE "  access      - Targets' access related commands"
      MESSAGE "  misc        - Misc commands"
    MSG_INDENT_DEC
  else
    case "$*" in
      "all"         ) private_SHOW_HELP_ALL           ;;
      "user"        ) private_SHOW_HELP_USERS         ;;
      "user conf"   ) private_SHOW_HELP_USER_CONF     ;;
      "usergroup"   ) private_SHOW_HELP_USERGROUPS    ;;
      "target"      ) private_SHOW_HELP_TARGETS       ;;
      "target conf" ) private_SHOW_HELP_TARGET_CONF   ;;
      "access"      ) private_SHOW_HELP_TARGET_ACCESS ;;
      "misc"        ) private_SHOW_HELP_MISC          ;;
      *             ) ERROR "Unknown help section."   ;;
    esac
  fi
  return 0
}


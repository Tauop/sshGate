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
    MESSAGE "user list                                          - List all users"
    MESSAGE "user add <user> key <sshkey-file> mail <mail@addr> - add a new user"
    MESSAGE "user del <user>                                    - delete a user"
    MESSAGE "user <user> display conf                           - display user configuration"
    MESSAGE "user <user> set conf <var> <value>                 - set a variable in user configuration"
    MESSAGE "user <user> set conf <var>                         - delete a variable from the user configuration"
    MESSAGE "user <user> list usergroups                        - list group of user"
    MESSAGE "user <user> list targets                           - list targets hosts of user"
    MESSAGE "user <user> has access [<login>@]<target>          - tell if a user has access to a target host"
    MESSAGE "user <user> access info                            - list all target user has access to, and how"
    MESSAGE "user <user> access notify                          - notify the user about its access list (via mail)"
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
    MESSAGE "usergroup list                     - list all users groups"
    MESSAGE "usergroup add <group>              - create a users group"
    MESSAGE "usergroup del <group>              - delete a users group"
    MESSAGE "usergroup <group> list users       - list users of a group"
    MESSAGE "usergroup <group> add user <user>  - add an user into a group"
    MESSAGE "usergroup <group> del user <user>  - delete an user from a group"
    MESSAGE "usergroup <group> list targets     - list targets which usergroup has access to"
    MESSAGE "usergroup <group> access info      - list all target whose users of the group have access to"
  MSG_INDENT_DEC
  return 0
}

private_SHOW_HELP_TARGETS () {
  MSG_INDENT_INC
    MESSAGE "target list [<pattern>]                         - list all targets, whose name match <pattern> if given"
    MESSAGE "target add [<login>@]<target>                   - add a new target host, which will use the system-wide default sshkey"
    MESSAGE "target add [<login>@]<target> key <sshkey-file> - add a new target host, with a given private sshkey"
    MESSAGE "target del <target>                             - delete a target host"
    MESSAGE "target alias list                               - list all aliases of a target host"
    MESSAGE "target alias del <alias>                        - delete an alias name"
    MESSAGE "target <target> display conf                    - display target configuration file"
    MESSAGE "target <target> set conf <var> <value>          - set a variable in the target configuration file"
    MESSAGE "target <target> realname                        - print the real name of a target host"
    MESSAGE "target <target> add alias <alias>               - add an alias of target hostname"
    MESSAGE "target <target> del alias <alias>               - delete an alias of the target"
    MESSAGE "target <target> list aliases                    - list aliases of the target host"
    MESSAGE "target <target> access info                     - list all user who has access to target, and how"
  MSG_INDENT_DEC
  return 0
}

private_SHOW_HELP_TARGET_SSH () {
  MSG_INDENT_INC
    MESSAGE "target ssh test all                                             - test to ssh connectivity for all targets"
    MESSAGE "target ssh install all keys                                     - install public sshkey on all targets"
    MESSAGE "target ssh edit config                                          - edit global ssh configuration file"
    MESSAGE "target ssh display config                                       - display global ssh configuration file"
    MESSAGE "target [<login>@]<target> ssh test                              - test ssh connectivity for the target host"
    MESSAGE "target [<login>@]<target> ssh install key                       - install sshkey on the target host"
    MESSAGE "target <target> ssh use default key                             - remove specific sshkey for the target host, which will use the system-wide default sshkey"
    MESSAGE "target <target> ssh list logins                                 - list all avariable ssh login for the target host"
    MESSAGE "target <target> ssh add login <login>                           - add a ssh login for the target host"
    MESSAGE "target <target> ssh del login <login>                           - delete a ssh login for the target host"
    MESSAGE "target [<login>@]<target> ssh edit config [for <login>]         - edit the ssh configuration used to connect to <login>@<target>"
    MESSAGE "target [<login>@]<target> ssh display config [for <login>]      - display the ssh configuration used to connect to <login>@<target>"
    MESSAGE "target [<login>@]<target> ssh display full config [for <login>] - display the full ssh configuration used to connect to <login>@<target>"
  MSG_INDENT_DEC
  return 0

}

private_SHOW_HELP_TARGET_CONF () {
  MSG_INDENT_INC
    MESSAGE "List of all variables of a target configuration"
    MESSAGE "See 'help targets' for target's configuration commands"
    BR
    MESSAGE "DEFAULT_SSH_LOGIN - Default ssh login to use when connecting to the target host"
    MESSAGE "SSH_PROXY         - Target host to use has a proxy (used of ProxyCommand). format = [<login>@]<target_host>"
  MSG_INDENT_DEC
  return 0
}

private_SHOW_HELP_TARGET_ACCESS () {
  MSG_INDENT_INC
    MESSAGE "user <user> access info                                                - list all target user has access to, and how"
    MESSAGE "usergroup <group> access info                                          - list all target whose users of the group have access to"
    MESSAGE "target <target> access info                                            - list all user who has access to target, and how"
    MESSAGE "target [<login>@]<target> access [with <login>] list users             - list all users who can access to the target host"
    MESSAGE "target [<login>@]<target> access [with <login>] add user <user>        - give user access to a target host"
    MESSAGE "target [<login>@]<target> access [with <login>] del user <user>        - revoke user access of target host"
    MESSAGE "target [<login>@]<target> access [with <login>] list usergroups        - list all groups who can access to the target host"
    MESSAGE "target [<login>@]<target> access [with <login>] add usergroup <group>  - give group access to a target host"
    MESSAGE "target [<login>@]<target> access [with <login>] del usergroup <group>  - revoke group access of a target host"
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
    private_SHOW_HELP_TARGET_SSH
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
      MESSAGE "  target ssh  - Target ssh releated commands"
      MESSAGE "  target conf - Target configuration variable"
      MESSAGE "  access      - Access related commands"
      MESSAGE "  misc        - Misc commands"
    MSG_INDENT_DEC
  else
    case "$*" in
      "all"         ) private_SHOW_HELP_ALL           ;;
      "user"        ) private_SHOW_HELP_USERS         ;;
      "user conf"   ) private_SHOW_HELP_USER_CONF     ;;
      "usergroup"   ) private_SHOW_HELP_USERGROUPS    ;;
      "target"      ) private_SHOW_HELP_TARGETS       ;;
      "target ssh"  ) private_SHOW_HELP_TARGET_SSH    ;;
      "target conf" ) private_SHOW_HELP_TARGET_CONF   ;;
      "access"      ) private_SHOW_HELP_TARGET_ACCESS ;;
      "misc"        ) private_SHOW_HELP_MISC          ;;
      *             ) ERROR "Unknown help section."   ;;
    esac
  fi
  return 0
}


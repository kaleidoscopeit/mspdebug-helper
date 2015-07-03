#!/bin/bash

# ===============================================================================
# Debug messages helper
#
# parameters
# 
# [-v] session_dir command [command arguments]
# ===============================================================================

debug () {
	if [ "$1" = "-d" ]; then
		local DATE="[ "`date +"%b %d %H:%M:%S"`" ]"
		shift
	fi

	if [ -n "$VERBOSE" ]; then echo -n -e "$@">&2; fi
	echo -n -e $DATE "$@">>$paths_sessiondir"/session.log"
	echo -n -e $DATE "$@">>$paths_workdir"/session.log"
}

# ===============================================================================
# Read all passed parameters and enables switches
# ===============================================================================
function read_params {
	local newargv
	local count=0

	for (( i = 0 ; i < ${#argv[@]} ; i++ )); do
		case ${argv[$i]} in
			-v)
				VERBOSE=1
				;;
			*)
				newargv[$count]=${argv[$i]}
				(( count++ ))
		esac
	done

	unset argv

	for (( i = 0 ; i < ${#newargv[@]} ; i++ )); do
		argv[$i]=${newargv[$i]}
	done
}

# ===============================================================================
# MAIN
# ===============================================================================

# Get working directory
WORKDIR=$1; shift
SCRIPTDIR=`dirname "$(readlink -f "$0")"`
cd "$SCRIPTDIR"

# Toolkit imports
source $WORKDIR/settings
for i in modules/*; do
  source $i
done

# Builds the workdir structure
mkdir -p $paths_workdir/sessions
paths_sessiondir=$paths_workdir/current
 
# Arguments handling
echo $@ >> $paths_workdir"/arguments"
COMMAND=$1; shift
argv=("$@")
read_params

# Call command
type $COMMAND >/dev/null

if [ $? -eq 0 ]; then
  $COMMAND ${argv[@]}
  exit $?
else
  debug -d "mspdebughelper : command not recognized ($COMMAND)\n"
fi

exit 255
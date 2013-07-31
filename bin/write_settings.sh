#!/bin/bash

# ==============================================================================
# Creates setting file in the workdir and sets/updates its properties
#
# write_settings.sh [workdir] [property_name] [property_value]
#
# ==============================================================================

SCRIPTDIR=`dirname "$(readlink -f "$0")"`
DEBUG_FILE="/tmp/mspdebughelper_anonymous.log"
#SETTINGS_FILE=$SCRIPTDIR"/settings"
SETTINGS_FILE=$1"/settings"
cd "$SCRIPTDIR"

# ===============================================================================
# Debug messages helper
# ===============================================================================

debug () {
	if [ "$1" = "-d" ]; then
		local DATE="[ "`date +"%b %d %H:%M:%S"`" ]"
		shift
	fi

	echo -n -e $DATE "$@">>$DEBUG_FILE
}

# ==============================================================================
# Do the trick
# ==============================================================================

# directory not found
if [ ! -d `dirname "$1"` ] || [ "$1" == "" ]
then
	debug -d "write_settings : Directory not found ("`dirname "$1"`")\n"
	exit 1
fi

# cannot write into directory
if [ ! -e `dirname "$1"` ]
then
		debug -d "write_settings : Directory not writeable ("`dirname "$1"`")\n"
		exit 2
fi

# Creates setting file
if [ ! -e "$SETTINGS_FILE" ]; then touch "$SETTINGS_FILE"; fi

case "$2" in
	set)
		if [ `grep -c $3 $SETTINGS_FILE` = 0 ]; then
			debug -d "write_settings : Written property (" $3 "=" $4 ")\n"
			echo $3"="$4 >> $SETTINGS_FILE
		else
			debug -d "write_settings : Updated property (" $3 "=" $4 ")\n"
			NEWPROP=`echo $4 | sed -e 's/[\/&]/\\\\&/g'`
			sed -i "s/$3=.*/$3=$NEWPROP/" $SETTINGS_FILE
		fi
		;;

	del)
		if [ `grep -c $3 $SETTINGS_FILE` -gt 0 ]; then
			debug -d "write_settings : Removed property (" $3 "=" $4 ")\n"
			sed -i "s/$3=.*//" $SETTINGS_FILE
		fi
		;;
	*)
		debug -d "write_settings : command '$2' unknown\n"		
esac

exit 0

#!/bin/bash

# ===============================================================================
# Program monitor
# ===============================================================================

program_monitor () {
	local bound
	local progress=0
	local count=0
	local cprogress

	# get the size of the firmware file
	local size=`cat $paths_workdir/firmware.conf | cut -d'	' -f 4`

	# refresh the r-sorted gdb.log
	cat -n $paths_workdir/gdb.log | tail -n 30 | sort -nr>$paths_workdir/gdb_rev.log

	while read line; do

		# Find for the last 'bound' of gdebug
		bound=`echo $line | grep -c 'Bound to port'`
		if [ $bound -eq 1 -a $count -gt 0 ]; then
			break
		fi

		line=`echo $line | grep 'Writing' | sed 's/^[\t ]*[0-9]*[\t ]*Writing[\t ]*//g' | sed 's/bytes[. a-zA-Z0-9]*//g'`
		if [ -n "$line" ]; then
			progress=$(( progress+line ))
		fi

		(( count++ ))
	done < $paths_workdir/gdb_rev.log

	cprogress=$(( progress*100/size ))

	debug -d "program_monitor : Progress to $cprogress% ($progress of $size)\n"

	return $cprogress
}



# ===============================================================================
# Verify monitor
# ===============================================================================

verify_monitor () {
	local bound
	local progress=0
	local count=0
	local cprogress

	# get the size of the firmware file
	local size=`cat $paths_workdir/firmware.conf | cut -d'	' -f 4`

	# refresh the r-sorted gdb.log
	cat -n $paths_workdir/gdb.log | tail -n 30 | sort -nr>$paths_workdir/gdb_rev.log

	while read line; do

		# Find for the last 'bound' of gdebug
		bound=`echo $line | grep -c 'Bound to port'`
		if [ $bound -eq 1 -a $count -gt 0 ]; then
			break
		fi

		line=`echo $line | grep 'Reading' | sed 's/^[\t ]*[0-9]*[\t ]*Reading[\t ]*//g' | sed 's/bytes[. a-zA-Z0-9]*//g'`
		if [ -n "$line" ]; then
			progress=$(( progress+line ))
		fi

		(( count++ ))
	done < $paths_workdir/gdb_rev.log

	cprogress=$(( progress*100/size ))

	debug -d "verify_monitor : Progress to $cprogress% ($progress of $size)\n"

	return $cprogress
}

# ===============================================================================
# Debug messages helper
# ===============================================================================

debug () {
	if [ "$1" = "-d" ]; then
		local DATE="[ "`date +"%b %d %H:%M:%S"`" ]"
		shift
	fi

	if [ -n "$VERBOSE" ]; then echo -n -e "$@">&2; fi
	echo -n -e $DATE "$@">>$paths_workdir"/main.log"
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

SCRIPTDIR=`dirname "$(readlink -f "$0")"`
cd "$SCRIPTDIR"

# Toolkit imports
source settings
source find_device.sh
source select_target.sh
source select_firmware.sh
source open_debug_session.sh
source close_debug_session.sh
source check_debug_session.sh
source clean_debug_session.sh
source get_supported_targets.sh
source erase.sh
source do_program.sh
source verify.sh
source write_string.sh
source memory_dump.sh

# Builds the workdir structure
mkdir -p $paths_workdir/save

# Arguments handling
echo $@ >> $paths_workdir/arguments
COMMAND=$1
shift
argv=("$@")
read_params

# Switches to target function
case "$COMMAND" in
	find_device)
		find_device $argv
		;;
	get_supported_targets)
		get_supported_targets
		;;
	open_debug_session)
		open_debug_session
		;;
	close_debug_session)
		close_debug_session
		;;
	select_target)
		select_target $argv
		;;
	clean_debug_session)
		clean_debug_session
		;;
	select_firmware)
		select_firmware $argv
		;;
	program)
		program
		;;
	program_monitor)
		program_monitor
		;;
	verify)
		verify
		;;
	verify_monitor)
		verify_monitor
		;;
	erase)
		erase $argv
		;;
	write_string)
		write_string
		;;
	memory_dump)
		memory_dump $argv
		;;		
	*)
		debug -d "program : command not recognized ($COMMAND)\n"
		echo  "program : command not recognized ($COMMAND)"
		;;
esac

exit $?
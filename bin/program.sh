#!/bin/bash


# ===============================================================================
# Copy or download the firmware file locally when a debug session is open
# ===============================================================================

select_firmware () {
	local size
	local ret_val

	# Check session status
	check_debug_session
	ret_val=$?

	if [ "$ret_val" -ne "0" ]; then
		debug -d "select_firmware : session check failed.\n"
		return 3;
	fi

	# Remove any previous downloaded firmware file
	debug -d "select_firmware : remove any previous firmware cache ... "
	rm -f $paths_workdir/firmware.hex
	rm -f $paths_workdir/firmware.conf

	if [ -s $paths_workdir/firmware.hex ] ; then
		debug "FAIL\n"
		# ------ EXIT CODE ------ #
		return 5
	else
		debug "OK\n"
	fi

	# Detect the file origin (local or remote)
	if [ `echo "${argv[0]}" | grep -c 'http:\/\/'` = 1 ]; then
		debug -d "select_firmware : Download firmware file into fimware.hex (${argv[0]}) ... " 
		wget --output-document=$paths_workdir/firmware.hex ${argv[0]} 1>$paths_workdir/wget.log 2>$paths_workdir/wget.log
		BASENAME=`basename "${argv[0]}"`
	else
		debug -d "select_firmware : Copy firmware file into fimware.hex ... "
		cp "${argv[0]}" "$paths_workdir/firmware.hex"
		BASENAME=`basename "$(readlink -f "${argv[0]}")"`
	fi

	if [ -s $paths_workdir/firmware.hex ] ; then
		debug "OK\n"
		# count the size of the firmware file
		while read line; do
			size=$(( size+0x${line:1:2} ))
		done < $paths_workdir/firmware.hex

		# write firmware data
		echo `dirname "${argv[0]}"`"	$BASENAME	"`md5sum $paths_workdir/firmware.hex | cut -f1 -d' '`"	"$size>$paths_workdir/firmware.conf

		# ------ EXIT CODE ------ #
		return 0
	else
		debug "FAIL\n"
		# ------ EXIT CODE ------ #
		return 4
	fi

	# ------ EXIT POINT------ unmanaged error #
	return 1
}


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
# Writes a string in a specified memory address
# ===============================================================================

write_string () {
	local SWITCH
	local ADDRESS
	local VALUE
	local BATCH

	mkdir $paths_workdir/ws_buffer

	# Find for any already started session
	check_debug_session
	local ret_val=$?

	if [ "$ret_val" -ne "0" ]; then
		debug -d "write_string : session check failed.\n"
		# ------ EXIT CODE ------ #
		return 3;
	fi

	# At least one pair address/string has to be given
	if [ -z "${argv[0]}" ]; then
		debug -d "write_string : Wrong parameter passed to function.\n"
		return 4
	fi

	# initialize batch files
	echo "target remote localhost:2000">$paths_workdir/gdb.batch
	echo >$paths_workdir/gdb.batch.erase
	echo >$paths_workdir/gdb.batch.mw
	echo >$paths_workdir/gdb.batch.dump

	debug -d "write_string : Making batch...\n"

	# Parse the given address/string pairs and creates 3 array with : start adress, string data, occupied memory size
	for (( i = 0 ; i < ${#argv[@]} ; i++ )); do
		ADDRESS[$i]=`echo ${argv[$i]} | cut -f1 -d' '`
		DATA[$i]=`echo ${argv[$i]} | cut -f2 -d' '`
		SIZE[$i]=`echo -n ${DATA[$i]} | wc -m`
		debug -d "write_string : Address->${ADDRESS[$i]},Data->'${DATA[$i]}',Size->${SIZE[$i]}\n"

		# Convert passed value to an exadecimal blob
		DATA_HEX[$i]="`echo -n ${DATA[$i]} | od -A n -t x1 |sed 's/^ //g'`"

		# compose batch file
		echo "monitor erase segment ${ADDRESS[$i]} ${SIZE[$i]}">>$paths_workdir/gdb.batch.erase
		echo "monitor mw ${ADDRESS[$i]} ${DATA_HEX[$i]}">>$paths_workdir/gdb.batch.mw
		echo "dump bin memory $paths_workdir/ws_buffer/${ADDRESS[$i]}.bin ${ADDRESS[$i]} `printf '0x%x\n' $(( ${ADDRESS[$i]}+${SIZE[$i]} ))`">>$paths_workdir/gdb.batch.dump
	done

	cat $paths_workdir/gdb.batch.erase $paths_workdir/gdb.batch.mw $paths_workdir/gdb.batch.dump >> $paths_workdir/gdb.batch

	debug -d "write_string : write data ... "
	echo "---------- WRITE STRING ON DATE `date +"%b %d %H:%M:%S"` ----------">>$paths_workdir/command_shots.log
	./msp430-gdb --batch -x $paths_workdir/gdb.batch >>$paths_workdir/command_shots.log 2>$paths_workdir/write_string_error.log

	local status=$?

	if [ $status != "0" ]; then
		debug "FAIL\n"
		debug -d "write_string : msp430-gdb command failed.\n"
		return 5
	fi

	debug "OK\n"

	for (( i = 0 ; i < ${#ADDRESS[@]} ; i++ )); do
		debug -d "write_string : verify data for address : ${ADDRESS[$i]} ... "
		if [ "`cat $paths_workdir/ws_buffer/${ADDRESS[$i]}.bin`" == "${DATA[$i]}" ];then
			debug "OK\n"
			return 0
		else
			debug "FAIL\n"
			debug -d "write_string : operation failed.\n"
			return 5
		fi
	done

	return 1
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
source open_debug_session.sh
source close_debug_session.sh
source check_debug_session.sh
source clean_debug_session.sh
source get_supported_targets.sh
source erase.sh
source do_program.sh
source verify.sh

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
	*)
		debug -d "program : command not recognized ($COMMAND)\n"
		echo  "program : command not recognized ($COMMAND)"
		;;
esac

exit $?
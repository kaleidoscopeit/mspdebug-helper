#!/bin/bash

# ===============================================================================
# Stops a debug session
# ===============================================================================

close_debug_session () {
	local COUNTER=0
	local PID

	# Check session status
	check_debug_session
	local ret_val=$?

	if [ "$ret_val" -eq "1" ]; then
		# ------ EXIT POINT------ debug session already started #
		debug -d "close_debug_session : Cannot close a non existent session.\n"
		return 3;
	fi

	if [ "$ret_val" -ne "0" ]; then
		# ------ EXIT POINT------ debug session already started #
		debug -d "close_debug_session : Try to close all foreing session.\n"
		killall -9 mspdebug 2>&1 >/dev/null

		# Waits 5 second the shutdown of gdb-proxy
		debug -d "close_debug_session : Wait for foreing session to stop... "
		while [ $COUNTER -lt 5 ]; do
				if [ -z "`ps -A | grep mspdebug`" ]; then
				debug "OK\n"

				# ------ EXIT POINT------ debug proxy stopped #
				return 0
			else
				sleep 1
				(( COUNTER++ ))
				debug $COUNTER' '
			fi
		done
	else
		PID=$((`cat $paths_workdir/gdb.pid`))
		kill $((`cat $paths_workdir/gdb.pid`)) 2>&1 >/dev/null

		# Waits 5 second the shutdown of gdb-proxy
		debug -d "close_debug_session : Wait for gdb-proxy stop... "
		while [ $COUNTER -lt 5 ]; do
				if [ -z "`ps -p "$PID"| grep "$PID"`" ]; then
				debug "OK\n"

				# ------ EXIT POINT------ debug proxy stopped #
				return 0
			else
				sleep 1
				(( COUNTER++ ))
				debug $COUNTER' '
			fi
		done
	fi


	# ------ EXIT POINT------ unmanaged error #
	return 1
}

# ===============================================================================
# Remove al debug files - NOT FULLY IMPLEMENTED
# ===============================================================================

clean_debug_session () {
	# Check session status
	check_debug_session
	local ret_val=$?

	if [ "$ret_val" -eq "0" ]; then
		# ------ EXIT POINT------ debug session already started #
		debug -d "clean_debug_session : Cannot clean an active session.\n"
		return 3;
	fi

	rm -r $paths_workdir/target.conf

	# ------ EXIT POINT------ clean done #
	debug -d "clean_debug_session : Session data erased.\n"
	return 0
}

# ===============================================================================
# Determines the session startup based on a target device id
# ===============================================================================

select_target () {
	if [ -z "$1" ]; then
		debug -d "select_target : Target name not supplied.\n"
		# ------ EXIT POINT------ target name not supplied #
		return 4
	fi

	check_debug_session
	local ret_val=$?

	if [ "$ret_val" -eq "0" ] ; then
		# ------ EXIT POINT------ debug session already started #
		debug -d "select_target : Session already started.\n"
		return 3;
	fi

	echo $1>$paths_workdir/target.conf

	if [ "`cat $paths_workdir/target.conf`" == "$1" ]; then
		# ------ EXIT POINT------ everything well #
		debug -d "select_target : Target selected -> $1.\n"
		return 0
	fi

	# ------ EXIT POINT------ unmanaged error #
	return 1
}

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
# Executes batch program;always use the firmware "$paths_workdir"/firmware.hex";
# see down_firmware function
# ===============================================================================

program () {
	# Find for any already started session
	check_debug_session
	local ret_val=$?

	if [ "$ret_val" -ne "0" ]; then
		debug -d "program : session check failed.\n"
		return 3;
	fi

	if [ ! -s $paths_workdir/firmware.hex -o ! -s $paths_workdir/firmware.conf ] ; then
		debug -d "program : Firmware not selected.\n"
		# ------ EXIT CODE ------ #
		return 4
	fi

	local FIRMWARE=$paths_workdir/firmware.hex
	local FIRMWARE_PATH=`cat $paths_workdir/firmware.conf | cut -d'	' -f 1`
	local FIRMWARE_NAME=`cat $paths_workdir/firmware.conf | cut -d'	' -f 2`
	local FIRMWARE_MD5=`cat $paths_workdir/firmware.conf | cut -d'	' -f 3`

	debug -d "program : Load required firmware ($FIRMWARE_NAME) into microprocessor memory... "

	echo "---------- PROGRAM ON DATE `date +"%b %d %H:%M:%S"` ----------">>$paths_workdir/command_shots.log

	./msp430-gdb --batch \
		-ex "target remote localhost:2000"\
		-ex "monitor prog "$FIRMWARE >>$paths_workdir/command_shots.log 2>$paths_workdir/program_error.log

	ret_val=$((`cat $paths_workdir/program_error.log | grep -c -i 'Load failed'`))

	if [ $ret_val != "0" ]; then
		debug "FAIL.\n"
		# ------ EXIT CODE ------ #
		return 5
	fi

	debug "OK.\n"
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
# Verify the target firmware
# ===============================================================================

verify () {
	# Find for any already started session
	check_debug_session
	local ret_val=$?

	if [ "$ret_val" -ne "0" ]; then
		debug -d "verify : session check failed.\n"
		# ------ EXIT CODE ------ #
		return 3;
	fi

	rm -r $paths_workdir/down_buffer/
	rm -r $paths_workdir/orig_buffer/
	mkdir $paths_workdir/down_buffer
	mkdir $paths_workdir/orig_buffer

	# Verify the complete cleanup of the cache directory
	if [ "`ls -l $paths_workdir/orig_buffer | grep -c '.*.hex'`" != "0" -o "`ls -l $paths_workdir/down_buffer | grep -c '.*.hex'`" != "0" ]; then
		debug -d "verify : cache directories not clean.\n"
		return 4
	fi

	# local defines
	local START="0x0000"
	local ORIG_START=$START
	local LENGTH="0x0000"
	local FILE=$ORIG_START".hex"
	local EXP_NEXT
	local TYPE
	local BATCH
	local DIFF_A
	local DIFF_B
	local COUNT
	local ORIG_CHUNKS
	local TARGET_CHUNKS

	# Check if the firmware file exists and its size is not zero
	if [ ! -s $paths_workdir/firmware.hex ]; then
		debug -d "verify : Firmware file error.\n"
		return 4;
	fi

	# Read from source file and split it in sectors
	debug -d "verify : Split source file ... "

	while read line; do
	#	debug -n "."
		# Obtain the expected address in the next line according to start address and the specified row length
 		EXP_NEXT=$(( $START + $LENGTH ))

		# Obtain key parameter from the current parsed line
		START="0x"${line:3:4}
		LENGTH="0x00"${line:1:2}
		TYPE=${line:7:2}

		# If the current row address is not as expected start a new sector
		if [ $EXP_NEXT != $(( $START )) ]; then
			# Prevent null data dump
			if [ $(( $ORIG_START )) != $EXP_NEXT ]; then
				BATCH=$BATCH"-ex 'dump ihex memory $paths_workdir/down_buffer/$FILE $ORIG_START $EXP_NEXT' "
				cat $paths_workdir/orig_buffer/$FILE".tmp" >$paths_workdir/orig_buffer/$FILE
				echo -e ":00000001FF\r">>$paths_workdir/orig_buffer/$FILE
				rm $paths_workdir/orig_buffer/$FILE".tmp"
			fi

			ORIG_START=$START
			FILE=$ORIG_START".hex"
	 	fi

		# Write only if there are datas
		if [ "$TYPE" = "00" ]; then
			echo $line>>$paths_workdir/orig_buffer/$FILE".tmp"
		fi
	done < $paths_workdir/firmware.hex


	local sector_list=`ls $paths_workdir/orig_buffer | grep '.*.hex'`
	local orig_chunks=`ls -l $paths_workdir/orig_buffer | grep -c '.*.hex'`
	local firmware_size=`cat $paths_workdir/firmware.conf | cut -d'	' -f 4`
	local orig_size
	local down_size

	# Check if firmware splitting has worked
	if [ "$orig_chunks" == "0" ];then
		debug "FAIL.\n"
		debug -d "verify : Result of firmware split is zero chunks.\n"
		# ------ EXIT CODE ------ #
		return 4
	fi

	# count the total size of the chunks files and compares with the size of the local firmware file
	for file in $sector_list; do
		while read line; do
			orig_size=$(( orig_size+0x${line:1:2} ))
		done < $paths_workdir/orig_buffer/$file
	done

	if [ "$firmware_size" != "$orig_size" ]; then
		debug "FAIL.\n"
		debug -d "verify : Original firmware file size and splitted chunk size differ.\n"
		# ------ EXIT CODE ------ #
		return 4
	fi

	debug "OK.\n"
	debug -d "verify : Original firmware file size -> $firmware_size, splitted chunk size -> $orig_size.\n"

	# Short report
	debug -d "verify : found $orig_chunks chunks.\n"
	debug "`ls $paths_workdir/orig_buffer`\n"

	debug -d "verify : Download firmware from target memory... "

	echo "---------- VERIFY ON DATE `date +"%b %d %H:%M:%S"` ----------">>$paths_workdir/command_shots.log
	eval './msp430-gdb --batch -ex "target remote localhost:2000" '$BATCH '>>$paths_workdir/command_shots.log 2>$paths_workdir/verify_error.log'

	# Check if the corresponding chunk was downloaded from target memory
	local target_chunks=`ls -l $paths_workdir/down_buffer | grep -c '.*.hex'`
	if [ "$orig_chunks" != "$target_chunks" ];then
		debug "FAIL.\n"
		debug -d "verify : Original chunks number differ than downloaded chunk number ($target_chunks instead of $orig_chunks).\n"
		# ------ EXIT CODE ------ #
		return 5;
	fi

	# count the total size of the downloaded chunks files and compares with the size of the local firmware file
	for file in $sector_list; do
		while read line; do
			down_size=$(( down_size+0x${line:1:2} ))
		done < $paths_workdir/down_buffer/$file
	done

	if [ "$firmware_size" != "$down_size" ]; then
		debug "FAIL.\n"
		debug -d "verify : Original firmware file size and downloaded chunks size differ.\n"
		# ------ EXIT CODE ------ #
		return 5
	fi

	debug "OK.\n"
	debug -d "verify : Original firmware file size -> $firmware_size, splitted chunk size -> $down_size.\n"


	# Finally compares the serctors file, one obtained from the original file and other obtained from the microprocessor memory
	SECTORS_LIST=`ls $paths_workdir/orig_buffer | grep '.*.hex'`
	COUNT=0
	for FILE in $SECTORS_LIST; do
		debug -d "verify : Verify data chunk for file $FILE..."
		DIFF_A=`md5sum -b $paths_workdir/orig_buffer/$FILE | cut -f1 -d' '`
		DIFF_B=`md5sum -b $paths_workdir/down_buffer/$FILE | cut -f1 -d' '`
		if [ "$DIFF_A" != "$DIFF_B" ]; then
			debug "FAIL\n"
			echo "verify : chunk file '$FILE' didn't match."
			return 6
		else
			debug "OK\n"
			(( COUNT++))
		fi
	done

	debug -d "verify : All worked without any interruption\n."
	# Further security check : compares the number of correct chunk verified with le number of analyzed chunks
	#return 1
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
# Check debug session status
# ===============================================================================

check_debug_session () {
	local NO_SESSION="0"

	# Find for any already started session
	if [ ! -e $paths_workdir/gdb.pid ]; then
		debug -d "check_debug_session : Session inexistent.\n"
		local NO_SESSION="1"
	else 
		local PID=`cat $paths_workdir/gdb.pid`

		if [ -z "`ps -p "$PID" | grep "$PID"`" ]; then
			debug -d "check_debug_session : Session not started.\n"
			local NO_SESSION="1"
		fi
	fi

	# Checks if there are debug sessions already started not owned by this tool
	MSPDEBUG_PID=`ps aux | grep mspdebug.*tilib.*gdb | grep -c -v grep`

	if [ "$MSPDEBUG_PID" -ne "0" ] && [ $NO_SESSION -eq "1" ]; then
		debug -d "check_debug_session : A session is already started but is not managed by this tool.\n"
		return 2
	fi

	if [ $NO_SESSION -eq "1" ]; then
		# ------ EXIT POINT------ debug session not started #
		return 1
	fi

	debug -d "check_debug_session : Session already started.\n"
	return 0
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
source open_debug_session.sh
source get_supported_devices.sh
source erase.sh

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
	get_supported_devices)
		get_supported_devices
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

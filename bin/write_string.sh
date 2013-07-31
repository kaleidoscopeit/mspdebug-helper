#/bin/bash

# ===============================================================================
# Writes a string in a specified memory address
# ===============================================================================

write_string () {
	local SWITCH
	local ADDRESS
	local VALUE
	local BATCH

	mkdir $paths_sessiondir/ws_buffer >/dev/null

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
	echo "target remote localhost:2000">$paths_sessiondir/gdb.batch
	echo >$paths_sessiondir/gdb.batch.erase
	echo >$paths_sessiondir/gdb.batch.mw
	echo >$paths_sessiondir/gdb.batch.dump

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
		echo "monitor erase segment ${ADDRESS[$i]} ${SIZE[$i]}">>$paths_sessiondir/gdb.batch.erase
		echo "monitor mw ${ADDRESS[$i]} ${DATA_HEX[$i]}">>$paths_sessiondir/gdb.batch.mw
		echo "dump bin memory $paths_sessiondir/ws_buffer/${ADDRESS[$i]}.bin ${ADDRESS[$i]} `printf '0x%x\n' $(( ${ADDRESS[$i]}+${SIZE[$i]} ))`">>$paths_sessiondir/gdb.batch.dump
	done

	cat $paths_sessiondir/gdb.batch.erase $paths_sessiondir/gdb.batch.mw $paths_sessiondir/gdb.batch.dump >> $paths_sessiondir/gdb.batch

	debug -d "write_string : write data ... "
	
	echo "---------- WRITE STRING ON DATE `date +"%b %d %H:%M:%S"` ----------">>$paths_sessiondir/command_shots.log

  COMMAND="$paths_msp430gdb --batch"
	COMMAND="$COMMAND -x $paths_sessiondir/gdb.batch"
  COMMAND="$COMMAND >>$paths_sessiondir/command_shots.log"
  COMMAND="$COMMAND 2>$paths_sessiondir/write_string_error.log"

  echo $COMMAND>>$paths_sessiondir/command_shots.log
  
  eval $COMMAND

	local status=$?

	if [ $status != "0" ]; then
		debug "FAIL\n"
		debug -d "write_string : msp430-gdb command failed.\n"
		return 5
	fi

	debug "OK\n"

	for (( i = 0 ; i < ${#ADDRESS[@]} ; i++ )); do
		debug -d "write_string : verify data for address : ${ADDRESS[$i]} ... "
		if [ "`cat $paths_sessiondir/ws_buffer/${ADDRESS[$i]}.bin`" == "${DATA[$i]}" ];then
			debug "OK\n"
		else
			debug "FAIL\n"
			debug -d "write_string : operation failed.\n"
			return 5
		fi
	done

	return 1
}
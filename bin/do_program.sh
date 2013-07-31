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

	if [ ! -s $paths_sessiondir/firmware.hex -o ! -s $paths_sessiondir/firmware.conf ] ; then
		debug -d "program : Firmware not selected.\n"
		# ------ EXIT CODE ------ #
		return 4
	fi

	local FIRMWARE=$paths_sessiondir/firmware.hex
	local FIRMWARE_PATH=`cat $paths_sessiondir/firmware.conf | cut -d'	' -f 1`
	local FIRMWARE_NAME=`cat $paths_sessiondir/firmware.conf | cut -d'	' -f 2`
	local FIRMWARE_MD5=`cat $paths_sessiondir/firmware.conf | cut -d'	' -f 3`

	debug -d "program : Load required firmware ($FIRMWARE_NAME) into microprocessor memory... "

	echo "---------- PROGRAM ON DATE `date +"%b %d %H:%M:%S"` ----------">>$paths_sessiondir/command_shots.log

  COMMAND="$paths_msp430gdb --batch"
	COMMAND="$COMMAND -ex \"target remote localhost:2000\""
  COMMAND="$COMMAND -ex \"monitor prog \"$FIRMWARE"
  COMMAND="$COMMAND >>$paths_sessiondir/command_shots.log"
  COMMAND="$COMMAND 2>$paths_sessiondir/program_error.log"

  echo $COMMAND>>$paths_sessiondir/command_shots.log
  
  eval $COMMAND

	ret_val=$((`cat $paths_sessiondir/program_error.log | grep -c -i 'error'`))

	if [ $ret_val != "0" ]; then
		debug "FAIL.\n"
		# ------ EXIT CODE ------ #
		return 5
	fi

	debug "OK.\n"
}
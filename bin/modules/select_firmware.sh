# =============================================================================
# Copy or download the firmware file locally when a debug session is open
#
# returns :
#
# 0    -> firmware selected successfully
# 1    -> remove firmware cache failed
# 2    -> get firmware from source location failed
#
# 10   -> session not started
# 11   -> a running session is not managed by this tool 
#
# 255  -> unmanaged error
# =============================================================================


select_firmware () {
	local size
	local ret_val

  # Check session status
  check_debug_session
  ret_val=$?

  if [ "$ret_val" -ne "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "select_firmware : session check failed.\n"
    return $(( ret_val+9 ))
  fi

	# Remove any previous downloaded firmware file
	debug -d "select_firmware : remove any previous firmware cache ... "
	rm -f $paths_sessiondir/firmware.hex
	rm -f $paths_sessiondir/firmware.conf

	if [ -s $paths_sessiondir/firmware.hex ] ; then
	  # ------ EXIT BREAKPOINT ------ #
		debug "FAIL\n"
		return 1
	else
		debug "OK\n"
	fi

	# Detect the file origin (local or remote)
	if [ `echo "${argv[0]}" | grep -c 'http:\/\/'` = 1 ]; then
		debug -d "select_firmware : Download firmware file into fimware.hex (${argv[0]}) ... " 
		wget --output-document=$paths_sessiondir/firmware.hex "${argv[0]}"\
      1>$paths_sessiondir/wget.log 2>$paths_sessiondir/wget.log
		BASENAME=`basename "${argv[0]}"`
	else
		debug -d "select_firmware : Copy firmware file into fimware.hex ... "
		cp "${argv[0]}" "$paths_sessiondir/firmware.hex"
		BASENAME=`basename "$(readlink -f "${argv[0]}")"`
	fi

	if [ -s $paths_sessiondir/firmware.hex ] ; then
		# count the size of the firmware file
		while read line; do
		  if [ "${line:7:2}" -eq "00" ]; then
        size=$(( size+0x${line:1:2} ))
		  fi
		done < $paths_sessiondir/firmware.hex

		# write firmware data
		echo `dirname "${argv[0]}"`"	$BASENAME	"`md5sum $paths_sessiondir/\
      firmware.hex | cut -f1 -d' '`"	"$size>$paths_sessiondir/firmware.conf

		# ------ EXIT BREAKPOINT ------ #
    debug "OK\n"
		return 0
	else
	  # ------ EXIT BREAKPOINT ------ #
		debug "FAIL\n"
		return 2
	fi

	# ------ EXIT POINT------ unmanaged error #
  debug -d "select_firmware : Unmanaged error.\n"
	return 255
}

# ===============================================================================
# Kill a foreign debug session
#
# returns :
#
# 0    -> no foreign mspdebug sessions or foreign sessions has killed
# 1    -> a foreign session still running 
# ===============================================================================

close_debug_session () {
	local COUNTER=0
	local PID

  # Check session status
  check_debug_session
  ret_val=$?

  if [ "$ret_val" -eq "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "close_debug_session : No foreign session detected.\n"
    return $ret_val;
  fi
  
	if [ "$ret_val" -ne "0" ]; then
		debug -d "close_debug_session : Try to close all foreing session.\n"
		killall -9 mspdebug 2>&1 >/dev/null

		# Waits 5 second the shutdown of gdb-proxy
		debug -d "close_debug_session : Wait for foreing session to stop... "
		while [ $COUNTER -lt 5 ]; do
		  if [ -z "`ps -C 'mspdebug' | grep -c mspdebug`" ]; then
				# ------ EXIT BREAKPOINT ------ #
        debug "OK\n"
				return 0
			else
				sleep 1
				(( COUNTER++ ))
				debug $COUNTER' '
			fi
		done
	fi

	# ------ EXIT POINT------ unmanaged error #
  debug "FAIL\n"
	return 1
}
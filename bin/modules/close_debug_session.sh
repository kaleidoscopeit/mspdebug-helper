# ===============================================================================
# Close a managed session
#
# accepts :
#
# kill  -> Closes a owned session and eventually tries to kill any foreign 
#          session
#
# returns :
#
# 0    -> no session or session closed gracefully
# 1    -> close session failed 
#
# 10    -> session not started
# 11    -> a running session is not managed by this tool 
# ===============================================================================

close_debug_session () {
	local COUNTER=0
	local PID	
	
  # Try to close all sessions
  if [ "$1" = "kill" ]; then
    debug -d "close_debug_session : Try to close all mspdebug session.\n"
    killall -9 mspdebug &>/dev/null

    # Waits 5 second the shutdown of gdb-proxy
    debug -d "close_debug_session : Wait for sessions to stop... "
    while [ $COUNTER -lt 5 ]; do
        if [ -z "`ps -C 'mspdebug' | grep -i mspdebug`" ]; then

        # ------ EXIT BREAKPOINT ------ #
        debug "OK\n"        
        return 0
      else
        sleep 1
        (( COUNTER++ ))
        debug $COUNTER' '
      fi
    done
    
    # ------ EXIT BREAKPOINT ------ #
		debug "FAIL\n"        
		return 1
  fi
    
  # Check session status
  check_debug_session
  ret_val=$?

  if [ "$ret_val" -ne "0" ]; then
    
    # ------ EXIT BREAKPOINT ------ #
    debug -d "close_debug_session : no session managed by this tool.\n"
    return $(( ret_val+9 ))
    
  else  
  
		debug -d "close_debug_session : Try to close managed session.\n"
		PID=`cat $paths_workdir/gdb.pid`
		kill -9 $PID 2>&1 >/dev/null

		# Waits 5 second the shutdown of gdb-proxy
		debug -d "close_debug_session : Wait for session to stop... "
		while [ $COUNTER -lt 5 ]; do
		  if [ -z "`ps -p "$PID" | grep "$PID"`" ]; then
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

	# ------ EXIT BREAKPOINT ------ #
  debug "FAIL\n"
	return 1
}
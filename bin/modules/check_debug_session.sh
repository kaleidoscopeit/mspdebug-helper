# ===============================================================================
# Check debug session status
#
# returns :
#
# 0    -> session already started
# 1    -> session not started
# 2    -> a running session is not managed by this tool 
# ===============================================================================

check_debug_session () {
  local PID
  
	# Find for any already started session
	if [ -e $paths_workdir/gdb.pid ]; then

    PID=`cat $paths_workdir/gdb.pid`

    if [ ! -z "`ps -p "$PID" | grep "$PID"`" ]; then
      
      # ------ EXIT BREAKPOINT ------ #
      debug -d "check_debug_session : Session already started.\n"
      return 0
    fi
    
  else
    	  
	  # Checks if there are debug sessions already started not owned by this tool
	  PID=`ps aux | grep mspdebug.*.*gdb | grep -c -v grep`
	
	  if [ "$PID" -ne "0" ]; then
      
      # ------ EXIT BREAKPOINT ------ #
      debug -d "check_debug_session : A session is already started "\
        "but is not managed by this tool.\n"
	    return 2
	  fi

	fi

  # ------ EXIT BREAKPOINT ------ #
  debug -d "check_debug_session : Session not started.\n"
  return 1
}
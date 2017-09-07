# ===============================================================================
# Check debug session status
#
# returns :
#
# 0    -> no mspdebug session is running
# 1    -> a foreign session is currently running 
# ===============================================================================

check_debug_session () {
	# Checks if there are a running mspdebug sessions
	MSPDEBUG_PID=`ps -C "mspdebug" | grep -c mspdebug`

  if [ "$MSPDEBUG_PID" -ne "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "check_debug_session : An mspdebug session is already started.\n"
    return 1
  fi

  # ------ EXIT BREAKPOINT ------ #
	debug -d "check_debug_session : No foreign session detected.\n"
	return 0
}
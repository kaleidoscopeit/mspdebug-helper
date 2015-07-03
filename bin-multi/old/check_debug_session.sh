# ===============================================================================
# Check debug session status
#
# returns :
#
# 0    -> session already started
# 1    -> session not started
# 2    -> a running session is not managed by this tool 
#
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
	MSPDEBUG_PID=`ps aux | grep mspdebug.*.*gdb | grep -c -v grep`

	if [ "$MSPDEBUG_PID" -ne "0" ] && [ $NO_SESSION -eq "1" ]; then
		debug -d "check_debug_session : A session is already started "\
		  "but is not managed by this tool.\n"
		  
		# ------ EXIT CODE ------ #
		return 2
	fi

	if [ $NO_SESSION -eq "1" ]; then
		# ------ EXIT CODE ------ #
		return 1
	fi

	debug -d "check_debug_session : Session already started.\n"
	
	# ------ EXIT CODE ------ #
	return 0
}
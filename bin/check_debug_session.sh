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

# ===============================================================================
# Stops debug session
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
		while [ $COUNTER -lt 10 ]; do
				if [ -z "`ps -p "$PID"| grep "$PID"`" ]; then
				debug "OK\n"

				# ------ EXIT POINT------ debug proxy stopped #
				return 0
			else
        debug "."
				sleep 1
				(( COUNTER++ ))
				debug $COUNTER' '
			fi
		done
	fi


	# ------ EXIT POINT------ unmanaged error #
	return 1
}
# ===============================================================================
# Starts a debug session
# ===============================================================================

new_session () {
	# local variables declaration
	local sessid=`date +"%d%m%y_%H%M%S"`

	check_debug_session
	local ret_val=$?

	if [ "$ret_val" -eq "0" ] ;
	then
		# ------ EXIT POINT------ debug session active #
		debug -d "new_session : Debug session active. A new workspace cannot be created\n"
		return 1;
	fi
  
	# Create a new session subdirectory and link as current in workdir
	mkdir $paths_workdir/sessions/$sessid
	rm $paths_sessiondir
	ln -fs $paths_workdir/sessions/$sessid $paths_sessiondir

	if [ "$ret_val" -ne "1" ] ;
	then
		# ------ EXIT POINT------ debug session already started #
		debug -d "new_session : Foreing session already started. Try to kill..."
		close_debug_session
		local ret_val=$?
		if [ "$ret_val" -ne "0" ] ;
		then
			debug -d "FAIL\n";
			return 2;
		fi

		debug -d "OK\n";
	fi

	# ------ EXIT POINT------ #
	debug -d "new_session : New session workspace created.\n"
	return 0;
}

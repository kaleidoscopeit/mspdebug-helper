# ===============================================================================
# Remove al debug files - NOT FULLY IMPLEMENTED
# ===============================================================================

clean_debug_session () {

	# Check session status
	check_debug_session
	local ret_val=$?

	if [ "$ret_val" -eq "0" ]; then
		# ------ EXIT POINT------ debug session already started #
		debug -d "clean_debug_session : Cannot clean an active session.\n"
		return 3;
	fi

	rm -r $paths_workdir/*

	# ------ EXIT POINT------ clean done #
	debug -d "clean_debug_session : Session data erased.\n"
	return 0
}
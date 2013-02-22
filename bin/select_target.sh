# ===============================================================================
# Determines the session startup based on a target device id
# ===============================================================================

select_target () {
	if [ -z "$1" ]; then
		debug -d "select_target : Target name not supplied.\n"
		# ------ EXIT POINT------ target name not supplied #
		return 4
	fi

	check_debug_session
	local ret_val=$?

	if [ "$ret_val" -eq "0" ] ; then
		# ------ EXIT POINT------ debug session already started #
		debug -d "select_target : Session already started. Target selection is possible only before starting a session\n"
		return 3;
	fi

	echo $1>$paths_workdir/target.conf

	if [ "`cat $paths_workdir/target.conf`" == "$1" ]; then
		# ------ EXIT POINT------ everything well #
		debug -d "select_target : Target selected -> $1.\n"
		return 0
	fi

	# ------ EXIT POINT------ unmanaged error #
	return 1
}
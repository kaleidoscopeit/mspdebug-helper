# =============================================================================
# Starts a debug session
#
# returns :
#
# 0    -> no mspdebug session is running
# 1    -> kill foreign session failed
# =============================================================================

new_session () {
	# local variables declaration
	local sessid=`date +"%d%m%y_%H%M%S"`

  check_debug_session
  local ret_val=$?

  if [ "$ret_val" -eq "1" ] ;
  then
    # ------ EXIT POINT------ debug session already started #
    debug -d "new_session : Foreing session already started. Try to kill..."
    close_debug_session
    local ret_val=$?
    if [ "$ret_val" -ne "0" ] ;
    then
      debug -d "FAIL\n";
      return 1;
    fi

    debug -d "OK\n";
  fi
  
	# Create a new session sub-directory and link as current in workdir
	mkdir $paths_workdir/sessions/$sessid
	rm $paths_sessiondir
	ln -fs $paths_workdir/sessions/$sessid $paths_sessiondir
  rm $paths_workdir"/session.log"

	# ------ EXIT POINT------ #
	debug -d "new_session : New session workspace created.\n"
	return 0
}

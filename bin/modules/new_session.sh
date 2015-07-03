# =============================================================================
# Creates a new work space
#
# accepts :
#
# kill  -> Closes a owned session and eventually tries to kill any foreign 
#          session
#
# returns :
#
# 0    -> new work space created
#
# 10    -> local session is active/still active
# 12    -> foreign session is active/still active
# =============================================================================

new_session () {
	# local variables declaration
	local sessid=`date +"%d%m%y_%H%M%S"`
  local ret_val

  # Try to close all sessions
  if [ "$1" = "kill" ]; then
    debug -d "new_session : Try to kill all sessions ... \n"
    
    # close debug session
    close_debug_session kill
    ret_val=$?

    if [ "$ret_val" -ne "0" ] ; then
      # ------ EXIT BREAKPOINT ------ #
      debug "FAIL\n"
      return 1
    fi
    
    debug "OK\n"
  fi  
  
  # Check session status
  check_debug_session
  ret_val=$?

  if [ "$ret_val" -ne "1" ]; then
    
    # ------ EXIT BREAKPOINT ------ #
    debug -d "new_session : A debug session is active. "\
      "A new workspace cannot be created\n"
    return $(( ret_val+10 ))
    
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

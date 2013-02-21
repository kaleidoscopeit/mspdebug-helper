# ==============================================================================
# Gets and format a list of compatible FET devices
# ==============================================================================

get_supported_devices() {
  
	# Starts a debug session
	if [ -n "$DEBUG" ]; then DEBUGSTRING=; fi
	COMMAND="$paths_mspdebug --fet-list"
  COMMAND="$COMMAND &>$paths_workdir/gdb.log &"
  
	debug -d "get_fet_devices : "$COMMAND"\n"

  eval  $COMMAND

}
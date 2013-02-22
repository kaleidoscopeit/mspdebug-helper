# ==============================================================================
# Gets and format a list of compatible FET devices
# ==============================================================================

get_supported_targets() {
  
	# Starts a debug session
	if [ -n "$DEBUG" ]; then DEBUGSTRING=; fi
	COMMAND="$paths_mspdebug --fet-list"
  COMMAND="$COMMAND &>$paths_workdir/gdb.log &"

  echo "---------- QUERY SUPPORTED TARGETS ON DATE `date +"%b %d %H:%M:%S"` ----------"\
    >>$paths_workdir/command_shots.log
    
  echo $COMMAND>>$paths_workdir/command_shots.log  

  eval  $COMMAND

}
# =============================================================================
# Update internal firmware of the TI FET
#
# returns :
#
# 0    -> update done
# 1    -> update error
# 2    -> debug tool issue
#
# 10   -> session already started
# 12   -> a running session is not managed by this tool

# =============================================================================

update_firmware () {
  # local variables declaration
  local paths_libmsp430=`dirname "$paths_libmsp430"`
  local TARGET
  local DEVICE
  local PID
  local COUNTER=0
  local DONE
  
  # Set the device path depending by the given driver
  if [ $driver != "tilib" ]; then
    # ------ EXIT BREAKPOINT ------ #
    anon_debug -d "upate_firmware : Driver is not compatible ($driver).\n"
    return 2
  fi
  
   # Check session status
  check_debug_session
  ret_val=$?

  if [ "$ret_val" -ne "1" ]; then
    # ------ EXIT BREAKPOINT ------ #
    anon_debug -d "upate_firmware : A debug session is already active.\n"
    return $(( ret_val+10 ))
  fi

  # Find if a debug tool exists depending by the given driver
  DEVICE=`find_device $driver`

  if [ -z "$DEVICE" ]; then
    # ------ EXIT BREAKPOINT ------ #
    anon_debug -d "upate_firmware : Cannot find a debug tool.\n"
    return 2
  fi

  if [ ! -w "$DEVICE" ]; then
    # ------ EXIT BREAKPOINT ------ #
    anon_debug -d "upate_firmware : Access denied to the debug tool. ($DEVICE)\n"
    return 2
  fi

  # Starts a debug session
  MSPDEBUG_CMD="LD_LIBRARY_PATH=$paths_libmsp430 $paths_mspdebug $driver "
  MSPDEBUG_CMD="$MSPDEBUG_CMD $link -d $DEVICE --allow-fw-update 'exit'"
  MSPDEBUG_CMD="$MSPDEBUG_CMD &>$paths_workdir/fet_fw_update.log "
  MSPDEBUG_CMD="$MSPDEBUG_CMD 2>$paths_workdir/fet_fw_update.log"

  anon_debug -d "upate_firmware : Start update\n"
    
  eval $MSPDEBUG_CMD

  # Checks if debug session were not started because no target was found (could never happen!)
  DONE=`cat $paths_workdir/fet_fw_update.log | grep -i 'Update complete'`
  
  if [ -n "$DONE" ];then
    # ------ EXIT BREAKPOINT ------ #
    anon_debug -d "upate_firmware : Update complete.\n"
    return 0
  fi

  # ------ EXIT BREAKPOINT ------ #
  anon_debug -d "upate_firmware : Update error.\n"
  return 1
}

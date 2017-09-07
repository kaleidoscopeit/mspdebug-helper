# ==============================================================================
# Verify the target firmware
#
# returns :
#
# 0    -> verify complete
# 1    -> verify failed
# 2    -> firmware not selected
#
# 10   -> a foreign session is currently running
# 11   -> cannot find debug tool
# 12   -> write access denied to the debug tool
# ==============================================================================

verify () {
  # Check if the firmware file exists and its size is not zero
  if [ ! -s $paths_sessiondir/firmware.hex -o \
       ! -s $paths_sessiondir/firmware.conf ] ; then
    debug -d "verify : Firmware not selected.\n"
    # ------ EXIT CODE ------ #
    return 2
  fi
  
  local FIRMWARE=$paths_sessiondir/firmware.hex
  
  # Check session status
  check_debug_session
  ret_val=$?

  if [ "$ret_val" -ne "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "verify : session check failed.\n"
    return $(( ret_val+9 ))
  fi
  
  # make the basic mspdebug command based upon settings
  make_command
  local ret_val=$?

  if [ "$ret_val" -ne "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "verify : make command failed.\n"
    return $(( ret_val+10 ))
  fi
  
  # start verify
  debug -d "verify : do verification using mspdebug internal feauture ... "

  echo "---------- VERIFY ON DATE `date +"%b %d %H:%M:%S"` ----------"\
    >>$paths_sessiondir/command_shots.log

  MSPDEBUG_CMD="$MSPDEBUG_CMD 'verify $FIRMWARE'"
  
  echo $MSPDEBUG_CMD>>$paths_sessiondir/command_shots.log

  echo >$paths_sessiondir/verify.log
  echo "---------------------">>$paths_sessiondir/gdb.log
  echo "VERIFY">>$paths_sessiondir/gdb.log
  echo "---------------------">>$paths_sessiondir/gdb.log
    
  eval $MSPDEBUG_CMD 2>$paths_sessiondir/verify_error.log | \
    tee -a $paths_sessiondir/gdb.log $paths_sessiondir/verify.log
    
  local ret_val=${PIPESTATUS[0]}

  # Checks if debug session were not started because no target was found (should never happen!)
  if [ "`cat $paths_sessiondir/program_error.log | grep 'code 4' | wc -l`" -ne "0" ];then
     # ------ EXIT BREAKPOINT ------ #
     cat $paths_sessiondir/verify_error.log >>$paths_sessiondir/gdb.log
    return 1
  fi

  if [ $ret_val == "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug "OK\n"
    return 0
  fi
    
  # ------ EXIT BREAKPOINT ------ #
  debug "FAIL\n"
  return 1
}
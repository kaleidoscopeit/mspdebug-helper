# =============================================================================
# Executes batch load without erase firmware;
#
# This function always uses the firmware "$paths_workdir"/firmware.hex", see
# select_firmware function.
#
# returns :
#
# 0    -> load complete
# 1    -> load failed
# 2    -> firmware not selected
#
# 10   -> a foreign session is currently running
# 11   -> cannot find debug tool
# 12   -> write access denied to the debug tool
# =============================================================================

load () {
  # Check session status
  check_debug_session
  ret_val=$?

  if [ "$ret_val" -ne "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "load : session check failed.\n"
    return $(( ret_val+9 ))
  fi
  
  # Check if the firmware file exists and its size is not zero
  if [ ! -s $paths_sessiondir/firmware.hex -o \
       ! -s $paths_sessiondir/firmware.conf ] ; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "program : Firmware not selected.\n"    
    return 2
  fi

  # call firmware stip
  strip_firmware
  ret_val=$?

  if [ "$ret_val" -ne "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "load : strip firmware failed.\n"
    return $ret_val
  fi

  # erase firmware areas
  for i in `ls $paths_sessiondir/firmware_stripped/*.conf`; do
    ./mspdebughelper.sh $paths_workdir erase range `cat $i | cut -d' ' -f1` `cat $i | cut -d' ' -f2`
  done

  local FIRMWARE=$paths_sessiondir/firmware.hex
  local FIRMWARE_PATH=`cat $paths_sessiondir/firmware.conf | cut -f 1`
  local FIRMWARE_NAME=`cat $paths_sessiondir/firmware.conf | cut -f 2`
  local FIRMWARE_MD5=`cat  $paths_sessiondir/firmware.conf | cut -f 3`
  local FIRMWARE_SIZE=`cat $paths_sessiondir/firmware.conf | cut -f 4`
  
  # make the basic mspdebug command based upon settings
  make_command
  local ret_val=$?

  if [ "$ret_val" -ne "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "load : make command failed.\n"
    return $(( ret_val+10 ))
  fi
  
  debug -d "load : Load required firmware ($FIRMWARE_NAME) into "\
    "microprocessor memory... "

  echo "---------- LOAD ON DATE `date +"%b %d %H:%M:%S"` ----------"
    >>$paths_sessiondir/command_shots.log
  
  MSPDEBUG_CMD="$MSPDEBUG_CMD 'load $FIRMWARE'"

  echo $MSPDEBUG_CMD>>$paths_sessiondir/command_shots.log
  
  echo >$paths_sessiondir/program.log
  echo "---------------------">>$paths_sessiondir/gdb.log
  echo "LOAD">>$paths_sessiondir/gdb.log
  echo "---------------------">>$paths_sessiondir/gdb.log
  
  eval $MSPDEBUG_CMD 2>$paths_sessiondir/program_error.log | \
    tee -a $paths_sessiondir/gdb.log $paths_sessiondir/program.log

  local ret_val=${PIPESTATUS[0]}

  # Checks if debug session were not started because no target was found (should never happen!)
  if [ "`cat $paths_sessiondir/program_error.log | grep 'code 4' | wc -l`" -ne "0" ];then
     # ------ EXIT BREAKPOINT ------ #
     cat $paths_sessiondir/program_error.log >>$paths_sessiondir/gdb.log
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
# ==============================================================================
# Verify the target firmware
#
# returns :
#
# 0    -> verify complete
# 1    -> verify failed
# 2    -> firmware not selected
#
# 10   -> session not started
# 11   -> a running session is not managed by this tool 
#
# ==============================================================================

verify () {
  # local variables declaration
  local GDB_CMD
  local ret_val
  local COUNTER=0
  
  # Check session status
  check_debug_session
  ret_val=$?

  if [ "$ret_val" -ne "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "verify : session check failed.\n"
    return $(( ret_val+9 ))
  fi  
  
  # Check if the firmware file exists and its size is not zero
  if [ ! -s $paths_sessiondir/firmware.hex -o \
       ! -s $paths_sessiondir/firmware.conf ] ; then
    debug -d "verify : Firmware not selected.\n"
    # ------ EXIT CODE ------ #
    return 2
  fi
  
  local FIRMWARE=$paths_sessiondir/firmware.hex
  local FIRMWARE_SIZE=`cat $paths_sessiondir/firmware.conf | cut -f 4`

  # start verify
  debug -d "verify : do verification using mspdebug internal feature ... \n"

  echo "---------- VERIFY ON DATE `date +"%b %d %H:%M:%S"` ----------"\
    >>$paths_sessiondir/command_shots.log

  GDB_CMD="$paths_msp430gdb --batch"
  GDB_CMD="$GDB_CMD -ex 'target remote localhost:2000'"
  GDB_CMD="$GDB_CMD -ex 'monitor verify $FIRMWARE'"

  echo $GDB_CMD>>$paths_sessiondir/command_shots.log

  echo "---------------------">>$paths_sessiondir/gdb.log
  echo "VERIFY">>$paths_sessiondir/gdb.log
  echo "---------------------">>$paths_sessiondir/gdb.log

  eval $GDB_CMD &>$paths_sessiondir/verify.log \
    2>$paths_sessiondir/verify.log
    
  FIRMWARE_SIZE=`cat $paths_sessiondir/verify.log | grep -i 'Done, '$FIRMWARE_SIZE | wc -l`
  if [ "$FIRMWARE_SIZE" -eq "1" ];then
    # ------ EXIT BREAKPOINT ------ #
    debug "OK\n"
    return 0
  fi
  
  # ------ EXIT BREAKPOINT ------ #
  debug "FAIL\n"
  return 1
}
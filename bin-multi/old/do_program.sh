# =============================================================================
# Executes batch program;
#
# This function always uses the firmware "$paths_workdir"/firmware.hex", see
# select_firmware function.
#
# returns :
#
# 0    -> program complete
# 1    -> program failed
# 2    -> firmware not selected
# 9    -> session check failed
#
# =============================================================================

program () {
  # Find for any already started session
  check_debug_session
  local ret_val=$?

  if [ "$ret_val" -ne "0" ]; then
    debug -d "program : session check failed.\n"
    # ------ EXIT CODE ------ #
    return 9;
  fi
    
  # Check if the firmware file exists and its size is not zero
  if [ ! -s $paths_sessiondir/firmware.hex -o \
       ! -s $paths_sessiondir/firmware.conf ] ; then
    debug -d "program : Firmware not selected.\n"
    # ------ EXIT CODE ------ #
    return 2
  fi

    local FIRMWARE=$paths_sessiondir/firmware.hex
    local FIRMWARE_PATH=`cat $paths_sessiondir/firmware.conf | cut -f 1`
    local FIRMWARE_NAME=`cat $paths_sessiondir/firmware.conf | cut -f 2`
    local FIRMWARE_MD5=`cat $paths_sessiondir/firmware.conf | cut -f 3`
    local FIRMWARE_SIZE=`cat $paths_sessiondir/firmware.conf | cut -f 4`
  
    debug -d "program : Load required firmware ($FIRMWARE_NAME) into "\
      "microprocessor memory... "

    echo "---------- PROGRAM ON DATE `date +"%b %d %H:%M:%S"` ----------"
      >>$paths_sessiondir/command_shots.log

    COMMAND="$paths_msp430gdb --batch"
    COMMAND="$COMMAND -ex \"target remote localhost:2000\""
    COMMAND="$COMMAND -ex \"monitor prog \"$FIRMWARE"
    COMMAND="$COMMAND >>$paths_sessiondir/command_shots.log"
    COMMAND="$COMMAND 2>$paths_sessiondir/program.log"

    echo $COMMAND>>$paths_sessiondir/command_shots.log
  
    eval $COMMAND
ret_val=$?
debug $ret_val
    ret_val=$((`cat $paths_sessiondir/program.log | 
      grep -c -i "Done, $FIRMWARE_SIZE bytes total"`))

    if [ $ret_val = "1" ]; then
      debug "OK.\n"
      # ------ EXIT CODE ------ #
      return 0
    fi

    debug "FAIL.\n"
    return 1
}
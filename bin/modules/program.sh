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
#
# 10   -> session not started
# 11   -> a running session is not managed by this tool 
# =============================================================================

program () {
  # local variables declaration
  local GDB_CMD
  local ret_val
  
  # Check session status
  check_debug_session
  ret_val=$?

  if [ "$ret_val" -ne "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "program : session check failed.\n"
    return $(( ret_val+9 ))
  fi
  
  # Check if the firmware file exists and its size is not zero
  if [ ! -s $paths_sessiondir/firmware.hex -o \
       ! -s $paths_sessiondir/firmware.conf ] ; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "program : Firmware not selected.\n"    
    return 2
  fi

  local FIRMWARE=$paths_sessiondir/firmware.hex
  local FIRMWARE_PATH=`cat $paths_sessiondir/firmware.conf | cut -f 1`
  local FIRMWARE_NAME=`cat $paths_sessiondir/firmware.conf | cut -f 2`
  local FIRMWARE_MD5=`cat  $paths_sessiondir/firmware.conf | cut -f 3`
  local FIRMWARE_SIZE=`cat $paths_sessiondir/firmware.conf | cut -f 4`
  
  case $1 in
    fwmem)
      # call firmware strip
      strip_firmware
      ret_val=$?

      if [ "$ret_val" -ne "0" ]; then
        # ------ EXIT BREAKPOINT ------ #
        debug -d "program : strip firmware failed.\n"
        return $ret_val
      fi

      debug -d "program : Erase firmware memory ... \n" 
        
      # erase firmware areas
      for i in `ls $paths_sessiondir/firmware_stripped/*.conf`; do
        #./mspdebughelper.sh $paths_workdir 
        erase range `cat $i | cut -d' ' -f1` `cat $i | cut -d' ' -f2`
      done

      debug -d "program : Load required firmware ($FIRMWARE_NAME) into "\
        "microprocessor memory (will be erased only firmware addresses) ... "
          
      GDB_CMD="$paths_msp430gdb --batch"
      GDB_CMD="$GDB_CMD -ex 'target remote localhost:2000'"
      GDB_CMD="$GDB_CMD -ex 'monitor load $FIRMWARE'"
      ;;

    all)
      debug -d "program : Erase all memory ... \n" 
        
      # erase all memory (info+main)
      erase all

      debug -d "program : Load required firmware ($FIRMWARE_NAME) into "\
        "microprocessor memory (will be erased only firmware addresses) ... "
          
      GDB_CMD="$paths_msp430gdb --batch"
      GDB_CMD="$GDB_CMD -ex 'target remote localhost:2000'"
      GDB_CMD="$GDB_CMD -ex 'monitor prog $FIRMWARE'"
      ;;
      
    *)
      debug -d "program : Load required firmware ($FIRMWARE_NAME) into "\
        "microprocessor memory... "
  
		  GDB_CMD="$paths_msp430gdb --batch"
		  GDB_CMD="$GDB_CMD -ex 'target remote localhost:2000'"
		  GDB_CMD="$GDB_CMD -ex 'monitor prog $FIRMWARE'"
      ;;

  esac

  echo "---------- PROGRAM ON DATE `date +"%b %d %H:%M:%S"` ----------"
    >>$paths_sessiondir/command_shots.log
  
  echo $GDB_CMD>>$paths_sessiondir/command_shots.log

  echo "---------------------">>$paths_sessiondir/gdb.log
  echo "PROGRAM">>$paths_sessiondir/gdb.log
  echo "---------------------">>$paths_sessiondir/gdb.log
  
  eval $GDB_CMD &>$paths_sessiondir/program.log \
    2>$paths_sessiondir/program.log

  FIRMWARE_SIZE=`cat $paths_sessiondir/program.log | grep -i 'Done, '$FIRMWARE_SIZE | wc -l`
  if [ "$FIRMWARE_SIZE" -eq "1" ];then
    # ------ EXIT BREAKPOINT ------ #
    debug "OK\n"
    return 0
  fi
  
  # ------ EXIT BREAKPOINT ------ #
  debug "FAIL\n"
  return 1
}
# =============================================================================
# Writes a string in a specified memory address
#
# returns :
#
# 0    -> write string success
# 1    -> write string failed 
# 2    -> wrong arguments
#
# 10   -> a foreign session is currently running
# 11   -> cannot find debug tool
# 12   -> write access denied to the debug tool
# 255  -> unmanaged error
# =============================================================================

write_string () {
  local SWITCH
  local ADDRESS
  local VALUE
  local BATCH
  local HAS_VERIFIED

  # At least one pair address/string has to be given
  if [ -z "${argv[0]}" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "write_string : Wrong parameter passed to function.\n"
    return 2
  fi
  
  # Check session status
  check_debug_session
  ret_val=$?

  if [ "$ret_val" -ne "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "write_string : session check failed.\n"
    return $(( ret_val+9 ))
  fi
  
  rm -r $paths_sessiondir/ws_buffer >/dev/null
  mkdir $paths_sessiondir/ws_buffer >/dev/null
  
  # initialize batch files
  echo -n >$paths_sessiondir/write_string.batch
  echo -n >$paths_sessiondir/write_string.batch.erase
  echo -n >$paths_sessiondir/write_string.batch.mw
  echo -n >$paths_sessiondir/write_string.batch.dump

  debug -d "write_string : Making batch...\n"

  # Parse the given address/string pairs and creates 3 array with : 
  # start adress, string data, occupied memory size
  for (( i = 0 ; i < ${#argv[@]} ; i++ )); do
    ADDRESS[$i]=`echo ${argv[$i]} | cut -f1 -d' '`
    DATA[$i]=`echo ${argv[$i]} | cut -f2 -d' '`
    SIZE[$i]=`echo -n ${DATA[$i]} | wc -m`
    debug -d "write_string : Address->${ADDRESS[$i]},Data->'${DATA[$i]}',Size->${SIZE[$i]}\n"

    # Convert passed value to an exadecimal blob
    DATA_HEX[$i]="`echo -n ${DATA[$i]} | od -A n -t x1 |sed 's/^ //g'`"

    # compose batch file
    echo "erase segment ${ADDRESS[$i]}"\
      >>$paths_sessiondir/write_string.batch.erase
    echo "mw ${ADDRESS[$i]} ${DATA_HEX[$i]}"\
      >>$paths_sessiondir/write_string.batch.mw
    echo "save_raw ${ADDRESS[$i]} ${SIZE[$i]}\
      $paths_sessiondir/ws_buffer/${ADDRESS[$i]}.bin "\
      >>$paths_sessiondir/write_string.batch.dump
  done

  cat $paths_sessiondir/write_string.batch.erase\
    $paths_sessiondir/write_string.batch.mw\
    $paths_sessiondir/write_string.batch.dump\
    >> $paths_sessiondir/write_string.batch
  
  echo "exit" >> $paths_sessiondir/write_string.batch

  # make the basic mspdebug command based upon settings
  make_command
  local ret_val=$?

  if [ "$ret_val" -ne "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "write_string : make command failed.\n"
    return $(( ret_val+10 ))
  fi

  debug -d "write_string : write data ... "
  
  echo "---------- WRITE STRING ON DATE `date +"%b %d %H:%M:%S"` ----------"\
   >>$paths_sessiondir/command_shots.log
  
  MSPDEBUG_CMD="$MSPDEBUG_CMD -C $paths_sessiondir/write_string.batch 'exit'"

  echo $MSPDEBUG_CMD>>$paths_sessiondir/command_shots.log
  
  echo >$paths_sessiondir/write_string.log
  echo "---------------------">>$paths_sessiondir/gdb.log
  echo "WRITE STRING">>$paths_sessiondir/gdb.log
  echo "---------------------">>$paths_sessiondir/gdb.log
  
  eval $MSPDEBUG_CMD 2>$paths_sessiondir/write_string_error.log | \
    tee -a $paths_sessiondir/gdb.log $paths_sessiondir/write_string.log
  
  local ret_val=${PIPESTATUS[0]}

  # Checks if debug session were not started because no target was found (should never happen!)
  if [ "`cat $paths_sessiondir/write_string_error.log | wc -l`" -ne "0" ];then
    # ------ EXIT BREAKPOINT ------ #
    cat $paths_sessiondir/write_string_error.log >>$paths_sessiondir/gdb.log
    debug "FAIL\n"
    return 1
  fi

  if [ $ret_val != "0" ]; then
    debug "FAIL\n"
    # ------ EXIT BREAKPOINT ------ #
    debug -d "write_string : command failed.\n"
    return 1
  fi

  debug "OK\n"

  for (( i = 0 ; i < ${#ADDRESS[@]} ; i++ )); do
    debug -d "write_string : verify data for address : ${ADDRESS[$i]} ... "

    if [ "`cat $paths_sessiondir/ws_buffer/${ADDRESS[$i]}.bin`" == "${DATA[$i]}" ];then
      # ------ EXIT BREAKPOINT ------ #
      debug "OK\n"
    else
      debug "FAIL\n"
      # ------ EXIT BREAKPOINT ------ #
      debug -d "write_string : operation failed.\n"
      return 1
    fi
    
    HAS_VERIFIED=1;
  done

  # double check avoid unmanaged script exit
  if [ $HAS_VERIFIED == 1 ];then
    # ------ EXIT BREAKPOINT ------ #
    return 0
  fi
  
  # ------ EXIT BREAKPOINT ------ #
  debug -d "write_string : unamanged error.\n"
  return 255
}
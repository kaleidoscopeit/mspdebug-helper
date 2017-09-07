# ===============================================================================
# Erase helper - all, main, segment addess length
#
# returns :
#
# 0    -> erase done
# 1    -> erase failed 
# 2    -> wrong erase mode selected
#
# 10   -> a foreign session is currently running
# 11   -> cannot find debug tool
# 12   -> write access denied to the debug tool
# ===============================================================================

erase () {
  # Check session status
  check_debug_session
  ret_val=$?

  if [ "$ret_val" -ne "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "erase : session check failed.\n"
    return $(( ret_val+9 ))
  fi
  
  # make the basic mspdebug command based upon settings
  make_command
  local ret_val=$?

  if [ "$ret_val" -ne "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "write_string : make command failed.\n"
    return $(( ret_val+10 ))
  fi
  
  case $1 in
    all)
      debug -d "erase : Erase ALL target memory ... "
	
	    MSPDEBUG_CMD="$MSPDEBUG_CMD 'erase all'"
      ;;
  
	  main)
	    debug -d "erase : Erase MAIN target memory ... "
	
	    MSPDEBUG_CMD="$MSPDEBUG_CMD 'erase'"
	    ;;
  
    range)

      # At least one pair address/string has to be given
      if [ -z "$2" -o -z "$3" ]; then
        # ------ EXIT BREAKPOINT ------ #
        debug -d "erase : Wrong parameter number passed to the function.\n"
        return 3
      fi
    
      debug -d "erase : Erase RANGE from $2 to $3 in target memory ... "
      MSPDEBUG_CMD="$MSPDEBUG_CMD 'erase segrange $2 $(( $3-$2 )) 0x200' 'erase segment $3'"
      ;;
      
	  *)
	    # ------ EXIT BREAKPOINT ------ #
	    debug -d "erase : erase type not valid ($1)\n"
	    return 2
	    ;;
  esac

  echo "---------- ERASE SHOT ON DATE `date +"%b %d %H:%M:%S"` ----------"\
    >>$paths_sessiondir/command_shots.log
        
  echo $MSPDEBUG_CMD>>$paths_sessiondir/command_shots.log
  echo "---------------------">>$paths_sessiondir/gdb.log
  echo "ERASE">>$paths_sessiondir/gdb.log
  echo "---------------------">>$paths_sessiondir/gdb.log
  
  echo >$paths_sessiondir/erase.log
  
  eval $MSPDEBUG_CMD 2>$paths_sessiondir/erase_error.log | \
    tee -a $paths_sessiondir/gdb.log $paths_sessiondir/erase.log
  
  local ret_val=${PIPESTATUS[0]}

  # Checks if debug session were not started because no target was found (should never happen!)
  if [ "`cat $paths_sessiondir/erase_error.log | wc -l`" -ne "0" ];then
     # ------ EXIT BREAKPOINT ------ #
     cat $paths_sessiondir/erase_error.log >>$paths_sessiondir/gdb.log
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
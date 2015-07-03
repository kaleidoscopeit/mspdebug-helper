# ===============================================================================
# Determines the session startup based on a target device id
#
# returns :
#
# 0    -> target selected successfully
# 1    -> target name not supplied
# 2    -> error writing to the config file
# 3    -> connected target doesn't match required chip
# 4    -> no target connected
#
# 10   -> a foreign session is currently running
# 11   -> cannot find debug tool
# 12   -> write access denied to the debug tool
# ===============================================================================

select_target () {
  # local variables declaration
  local TARGET

  if [ -z "$1" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "select_target : Target name not supplied.\n"    
    return 1
  fi

  echo $1>$paths_sessiondir/target.conf
  TARGET=`cat $paths_sessiondir/target.conf`
  
  if [ "$TARGET" != "$1" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "select_target : Config file error -> $1.\n"
    return 2
  fi

  # Check session status
  check_debug_session
  ret_val=$?

  if [ "$ret_val" -ne "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "select_target : session check failed.\n"
    return $(( ret_val+9 ))
  fi
        
  # make the basic mspdebug command based upon settings
  make_command
  local ret_val=$?

  if [ "$ret_val" -ne "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "select_target : make command failed.\n"
    return $(( ret_val+10 ))
  fi

  # test a connection and lookup for results
  echo >$paths_sessiondir/target.log
  echo "---------------------">>$paths_sessiondir/gdb.log
  echo "SELECT TARGET">>$paths_sessiondir/gdb.log
  echo "---------------------">>$paths_sessiondir/gdb.log
  
  eval $MSPDEBUG_CMD 'exit' 2>$paths_sessiondir/target_error.log | \
    tee -a $paths_sessiondir/gdb.log $paths_sessiondir/target.log

  # Checks if debug session were not started because no target was found (should never happen!)
  if [ -n "`cat $paths_sessiondir/target_error.log | grep -i 'MSP430_OpenDevice: Unknown device'`" ];then
    # ------ EXIT POINT------ target not found #
     cat $paths_sessiondir/target_error.log >>$paths_sessiondir/gdb.log
    return 4
  fi
  
  # Checks if the desired target is auto
  if [ "$TARGET" == "auto" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "select_target : Success!!!\n"    
    return 0
  fi
  
  # Checks if the connected target and the desired chip match 
  if [ ! -z "`grep 'Device: '$TARGET $paths_sessiondir/target.log`" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "select_target : Success!!!\n"    
    return 0
  fi

	# ------ EXIT BREAKPOINT ------ #  
  debug -d "select_target : Specified target ($TARGET) not found.\n"
	return 3
}
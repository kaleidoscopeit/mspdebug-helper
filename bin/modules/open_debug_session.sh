# =============================================================================
# Starts a debug session
#
# returns :
#
# 0    -> session started successfully
# 1    -> wrong target/target not found
# 2    -> debug tool issue
#
# 10     -> session already started
# 12    -> a running session is not managed by this tool
#
# 255   -> unmanaged error
# =============================================================================

open_debug_session () {
	# local variables declaration
	local paths_libmsp430=`dirname "$paths_libmsp430"`
  local TARGET
  local DEVICE
  local PID
  local COUNTER=0
  local ERROR
 
   # Check session status
  check_debug_session
  ret_val=$?

  if [ "$ret_val" -ne "1" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "open_debug_session : A debug session is already active.\n"
    return $(( ret_val+10 ))
  fi

	# Find if a debug tool exists depending by the given driver
	DEVICE=`find_device $driver`

	if [ -z "$DEVICE" ]; then
    # ------ EXIT BREAKPOINT ------ #
		debug -d "open_debug_session : Cannot find a debug tool.\n"
		return 2
	fi

  if [ ! -w "$DEVICE" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "open_debug_session : Access denied to the debug tool. ($DEVICE)\n"
    return 2
  fi

  # Set the device path depending by the given driver
  if [ $driver = "tilib" ]; then
    DEVICE=`echo $DEVICE | sed -e 's/\/dev\///g'`;
  fi

  # set link type
  if [ $link = "jtag" ]; then link="-j"; else link=""; fi

  # Starts a debug session
  MSPDEBUG_CMD="LD_LIBRARY_PATH=$paths_libmsp430 $paths_mspdebug $driver "
  MSPDEBUG_CMD="$MSPDEBUG_CMD $link -d $DEVICE 'opt gdb_loop 1' 'gdb'"
  MSPDEBUG_CMD="$MSPDEBUG_CMD &>>$paths_sessiondir/gdb.log "
  MSPDEBUG_CMD="$MSPDEBUG_CMD 2>$paths_sessiondir/gdb_error.log &"
  
  echo "---------- START SESSION ON DATE `date +"%b %d %H:%M:%S"` ----------"\
    >>$paths_sessiondir/command_shots.log
    
  echo $MSPDEBUG_CMD>>$paths_sessiondir/command_shots.log
  
  echo "---------------------">>$paths_sessiondir/gdb.log
  echo "START SESSION">>$paths_sessiondir/gdb.log
  echo "---------------------">>$paths_sessiondir/gdb.log
  
  eval $MSPDEBUG_CMD

  # store pid
  PID=$!
  echo $PID>$paths_workdir/gdb.pid

  # Waits 10 second for the opening of gdb listening port (2000)
  debug -d "open_debug_session : Wait for gdb-proxy start... "
  while [ $COUNTER -lt 10 ]; do
    
    if [ ! -z "`tail -n1 $paths_sessiondir/gdb.log | grep 'Bound to port'`" ];
    then      
      debug "OK\n"

			# If a specific target was selected do checks
			if [ -e $paths_sessiondir/target.conf ];
			then
			  TARGET=`cat $paths_sessiondir/target.conf`
			  
				if [ -z "`grep $TARGET $paths_sessiondir/gdb.log`" -a "$TARGET" != "auto" ];
				then
				  close_debug_session
				  
				  # ------ EXIT BREAKPOINT ------ #
					debug -d "open_debug_session : Specified target ($TARGET) not found.\n"
					return 1
				fi
			fi

			# ------ EXIT BREAKPOINT ------ #
			return 0
		else
			sleep 1
			(( COUNTER++ ))
			debug $COUNTER' '
		fi
	done

  debug "FAIL\n"
  
  # close own session
  close_debug_session
  
  # Checks if debug session were not started because no target was found (could never happen!)
  ERROR=`cat $paths_sessiondir/gdb.log | grep -i 'MSP430_OpenDevice: Unknown device'`
  ERROR=$ERROR`cat $paths_sessiondir/gdb.log | grep -i 'Could not find device or device not supported'`
  
  if [ -n "$ERROR" ];then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "open_debug_session : No target found.\n"
    return 1
  fi

  # Check the access to the debug tool 
  if [ -n "`cat $paths_sessiondir/gdb_error.log | grep -i 'can\'t open serial device`" ];then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "open_debug_session : Resource busy. ($DEVICE)\n"
    return 2
  fi

  # ------ EXIT BREAKPOINT ------ #
  return 255
}

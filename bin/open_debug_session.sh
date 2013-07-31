# ===============================================================================
# Starts a debug session
# ===============================================================================

open_debug_session () {
	# local variables declaration
	local DEVICE
	local MSPDEBUG_PID
	local COUNTER=0
	local paths_libmsp430=`dirname "$paths_libmsp430"`
  local sessid=`date +"%d%m%y_%H%M%S"`

  # Create a session subdirectory and link as current in workdir
  mkdir $paths_workdir/sessions/$sessid
  rm $paths_sessiondir
  ln -s $paths_workdir/sessions/$sessid $paths_sessiondir
    
	check_debug_session
	local ret_val=$?

	if [ "$ret_val" -eq "0" ] ;
	then
		# ------ EXIT POINT------ debug session already started #
		debug -d "open_debug_session : Session already started.\n"
    return 3;

  elif [ "$ret_val" -ne "1" ] ;
  then
		# ------ EXIT POINT------ debug session already started #
		debug -d "open_debug_session : Foreing session already started. Try to kill\n"
		close_debug_session
	fi



	# Find if a debug tool exists depending by the given driver
	DEVICE=`find_device $driver`

	if [ -z "$DEVICE" ];
	then
		debug -d "open_debug_session : Cannot find a debug tool.\n"
		return 4
	fi

  if [ ! -w "$DEVICE" ]; then
    debug -d "open_debug_session : Write access denied to the debug tool. ($DEVICE)\n"
    return 5
  fi

  if [ $driver = "tilib" ]; then
    DEVICENAME=`echo $DEVICE | sed -e 's/\/dev\///g'`;
  else
    DEVICENAME=$DEVICE
  fi
  
  # set link type
  if [ $link = "jtag" ]; then link="-j"; fi
  
  # Starts a debug session
  echo "---------- START SESSION ON DATE `date +"%b %d %H:%M:%S"` ----------"\
    >>$paths_sessiondir/command_shots.log
 
  if [ -n "$DEBUG" ]; then DEBUGSTRING=; fi
  COMMAND="LD_LIBRARY_PATH=$paths_libmsp430 $paths_mspdebug $driver "
  COMMAND="$COMMAND --allow-fw-update $link -d $DEVICENAME 'opt gdb_loop 1' 'gdb' "
  COMMAND="$COMMAND &>$paths_sessiondir/gdb.log &"
  
  echo $COMMAND>>$paths_sessiondir/command_shots.log

  eval $COMMAND

  # store pid
  PID=$!
  echo $PID>$paths_workdir/gdb.pid

  # Waits 5 second for the opening of gdb listening port (2000)
  debug -d "open_debug_session : Wait for gdb-proxy start... "
  while [ $COUNTER -lt 10 ];
  do
    if [ ! -z "`tail -n1 $paths_sessiondir/gdb.log | grep 'Bound to port'`" ];
    then
      debug "OK\n"

			# If a specific target was selected do checks
			if [ -e $paths_workdir/target.conf ];
			then
				local TARGET=`cat $paths_workdir/target.conf`
				if [ -z "`grep $TARGET $paths_sessiondir/gdb.log`" -a "$TARGET" != "auto" ];
				then
					debug -d "open_debug_session : Specified target (`cat $paths_sessiondir/target.conf`) not found.\n"

					close_debug_session
					
					debug " OK\n"
					
					# ------ EXIT POINT------ target not found #
					return 6
				fi
			fi

			# ------ EXIT POINT------ debug proxy started #
			return 0
		else
			sleep 1
			(( COUNTER++ ))
			debug $COUNTER' '
		fi
	done


  # ------ EXIT POINT------ debug proxy failed #
  debug "FAIL\n"
  close_debug_session

  # Checks if debug session were not started because no target was found (could never happen!)
  if [ -n "`cat $paths_sessiondir/gdb.log | grep -i 'MSP430_OpenDevice: Unknown device'`" ];then
    # ------ EXIT POINT------ target not found #
    return 6
  fi

  # ------ EXIT POINT------ unmanaged error #
  return 1
}

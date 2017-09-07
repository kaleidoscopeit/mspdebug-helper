# ==============================================================================
# Read target memory
#
# returns :
#
# 0    -> dump memory done
# 1    -> dump memory failed
# 2    -> wrong arguments
#
# 10   -> a foreign session is currently running
# 11   -> cannot find debug tool
# 12   -> write access denied to the debug tool
# 255  -> unmanaged error
# ==============================================================================

memory_dump () {
  # Check session status
  check_debug_session
  ret_val=$?

  if [ "$ret_val" -ne "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "program : session check failed.\n"
    return $(( ret_val+9 ))
  fi

  mkdir $paths_sessiondir/dump_memory

  # make the basic mspdebug command based upon settings
  make_command
  local ret_val=$?

  if [ "$ret_val" -ne "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "program : make command failed.\n"
    return $(( ret_val+10 ))
  fi
  
  case $1 in
    all)
  		debug -d "memory_dump : Dump ALL target memory ... "
      local TARGET_FILE=$paths_sessiondir"/dump_memory/all.hex"
      $paths_sessiondir"/dump_memory/"
      echo $(( 0xFFFF ))>$paths_sessiondir"/memory_dump_size"
		  MSPDEBUG_CMD="$MSPDEBUG_CMD 'hexout 0x0000 0x1FFFF $TARGET_FILE'"
      ;;
    
    main)
  		debug -d "memory_dump : Dump MAIN target memory ... "
      local TARGET_FILE=$paths_sessiondir"/dump_memory/main.hex"
      echo $(( 0xEEFF-0x1100 ))>$paths_sessiondir"/memory_dump_size"
      MSPDEBUG_CMD="$MSPDEBUG_CMD 'hexout 0x1100 0x1FFFF $TARGET_FILE'"
      ;;
      
    info)
  		debug -d "memory_dump : Dump INFORMATIONAL target memory ... "
      local TARGET_FILE=$paths_sessiondir"/dump_memory/info.hex"
      echo $(( 0x10FF-0x1100 ))>$paths_sessiondir"/memory_dump_size"
      MSPDEBUG_CMD="$MSPDEBUG_CMD 'hexout 0x1100 0x10FF $TARGET_FILE'"
      ;;

    segment)
  		debug -d "memory_dump : Dump SEGMENTED target memory ... "

      local START=$(echo "$2" | grep "0x[0-9 A-F].")
      local END=$(echo "$3" | grep "0x[0-9 A-F].")
      local TARGET_FILE=$paths_sessiondir"/dump_memory/"$START".hex"
      
      if [ -z $START || -z $END ]; then
    		debug -d "memory_dump : Dump range not valid (from $2 to $3)\n"
        return 2
      fi
            
      echo $(( $END-$START ))>$paths_sessiondir"/memory_dump_size"
      MSPDEBUG_CMD="$MSPDEBUG_CMD 'hexout $START $END $TARGET_FILE'"
    	;;

    *)
  		debug -d "memory_dump : Dump type not valid ($1)\n"
      return 255
  	  ;;
  esac  

	echo "---------- DUMP MEMORY ON DATE `date +"%b %d %H:%M:%S"` ----------"\
	  >>$paths_sessiondir/command_shots.log
  		  
	echo $MSPDEBUG_CMD>>$paths_sessiondir/command_shots.log
	      
	echo >$paths_sessiondir/memory_dump.log
	echo "---------------------">>$paths_sessiondir/gdb.log
	echo "DUMP MEMORY">>$paths_sessiondir/gdb.log
	echo "---------------------">>$paths_sessiondir/gdb.log
	
	eval $MSPDEBUG_CMD 2>$paths_sessiondir/memory_dump_error.log | \
	  tee -a $paths_sessiondir/gdb.log $paths_sessiondir/memory_dump.log
    
  local ret_val=$?
    
  if [ $ret_val == "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug "OK\n"
    return 0
  fi
        
  # ------ EXIT BREAKPOINT ------ #
  debug "FAIL\n"
  return 1
}
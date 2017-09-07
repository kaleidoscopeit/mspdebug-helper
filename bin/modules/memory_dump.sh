# =============================================================================
# Read target memory
#
# returns :
#
# 0    -> dump memory done
# 1    -> dump memory failed
# 2    -> wrong arguments
#
# 10   -> session not started
# 11   -> a running session is not managed by this tool 
# =============================================================================

memory_dump () {
  # local variables declaration
  local GDB_CMD
  
  # Check session status
  check_debug_session
  ret_val=$?

  if [ "$ret_val" -ne "0" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "memory_dump : session check failed.\n"
    return $(( ret_val+9 ))
  fi

  mkdir $paths_sessiondir/dump_memory

  case $1 in
    all)
  		debug -d "memory_dump : Dump ALL target memory ... "
      local TARGET_FILE=$paths_sessiondir"/dump_memory/all.hex"
      $paths_sessiondir"/dump_memory/"
      echo $(( 0x1FFFF ))>$paths_sessiondir"/memory_dump_size"

      GDB_CMD="$paths_msp430gdb --batch"
      GDB_CMD="$GDB_CMD -ex \"target remote localhost:2000\""
      GDB_CMD="$GDB_CMD -ex \"dump ihex memory $TARGET_FILE 0x0000 0x1FFFF\""
      #GDB_CMD="$GDB_CMD -ex \"monitor md 0x0000 0x1FFFF\""
      ;;
    
    main)
  		debug -d "memory_dump : Dump MAIN target memory ... "
      local TARGET_FILE=$paths_sessiondir"/dump_memory/main.hex"
      echo $(( 0x1FFFF-0x1100 ))>$paths_sessiondir"/memory_dump_size"
      
      GDB_CMD="$paths_msp430gdb --batch"
      GDB_CMD="$GDB_CMD -ex \"target remote localhost:2000\""
      GDB_CMD="$GDB_CMD -ex \"dump ihex memory $TARGET_FILE 0x1100 0x1FFFF\""
      ;;
      
    info)
  		debug -d "memory_dump : Dump INFORMATIONAL target memory ... "
      local TARGET_FILE=$paths_sessiondir"/dump_memory/info.hex"
      echo $(( 0x10FF-0x1100 ))>$paths_sessiondir"/memory_dump_size"
      
      GDB_CMD="$paths_msp430gdb --batch"
      GDB_CMD="$GDB_CMD -ex \"target remote localhost:2000\""
      GDB_CMD="$GDB_CMD -ex \"dump ihex memory $TARGET_FILE 0x1000 0x10FF\""
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
      
      GDB_CMD="$paths_msp430gdb --batch"
      GDB_CMD="$GDB_CMD -ex \"target remote localhost:2000\""
      GDB_CMD="$GDB_CMD -ex \"dump ihex memory $TARGET_FILE $START $END\""
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
	
	eval $GDB_CMD &>$paths_sessiondir/memory_dump.log \
    2>$paths_sessiondir/memory_dump_error.log
    
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
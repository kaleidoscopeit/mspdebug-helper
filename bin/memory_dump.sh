# ==============================================================================
# Read target memory
# ==============================================================================

memory_dump () {
	# Find for any already started session
	check_debug_session
	local ret_val=$?

	if [ "$ret_val" -ne "0" ]; then
		debug -d "memory_dump : session check failed.\n"
		return 2;
	fi

  mkdir $paths_workdir/dump_memory
  
  case $1 in
    all)
  		debug -d "memory_dump : Dump ALL target memory ... "

      local TARGET_FILE=$paths_workdir"/dump_memory/all.hex"
        
      COMMAND="$paths_msp430gdb --batch"
  		COMMAND="$COMMAND -ex \"target remote localhost:2000\""
  	  COMMAND="$COMMAND -ex \"dump ihex memory $TARGET_FILE 0x0000 0xFFFF\""
  	  COMMAND="$COMMAND >>$paths_workdir/command_shots.log"
  	  COMMAND="$COMMAND 2>$paths_workdir/dump_memory_error.log"  
      ;;
    
    main)
  		debug -d "memory_dump : Dump MAIN target memory ... "

      local TARGET_FILE=$paths_workdir"/dump_memory/main.hex"
        
      COMMAND="$paths_msp430gdb --batch"
  		COMMAND="$COMMAND -ex \"target remote localhost:2000\""
  	  COMMAND="$COMMAND -ex \"dump ihex memory $TARGET_FILE 0x1100 0xFFFF\""
  	  COMMAND="$COMMAND >>$paths_workdir/command_shots.log"
  	  COMMAND="$COMMAND 2>$paths_workdir/dump_memory_error.log"
      ;;
      
    info)
  		debug -d "memory_dump : Dump INFORMATIONAL target memory ... "

      local TARGET_FILE=$paths_workdir"/dump_memory/info.hex"
        
      COMMAND="$paths_msp430gdb --batch"
  		COMMAND="$COMMAND -ex \"target remote localhost:2000\""
  	  COMMAND="$COMMAND -ex \"dump ihex memory $TARGET_FILE 0x1000 0x10FF\""
  	  COMMAND="$COMMAND >>$paths_workdir/command_shots.log"
  	  COMMAND="$COMMAND 2>$paths_workdir/dump_memory_error.log"
      ;;

    segment)
  		debug -d "memory_dump : Dump SEGMENTED target memory ... "

      local START=$(echo "$2" | grep "0x[0-9 A-F].")
      local END=$(echo "$3" | grep "0x[0-9 A-F].")
      local TARGET_FILE=$paths_workdir"/dump_memory/"$START".hex"
      
      if [ -z $START || -z $END ]; then
    		debug -d "memory_dump : Dump range not valid (from $2 to $3)\n"
        echo     "memory_dump : Dump range not valid (from $2 to $3)"
        return 255
      fi
      
      COMMAND="$paths_msp430gdb --batch"
  		COMMAND="$COMMAND -ex \"target remote localhost:2000\""
  	  COMMAND="$COMMAND -ex \"dump ihex memory $TARGET_FILE $START $END\""
  	  COMMAND="$COMMAND >>$paths_workdir/command_shots.log"
  	  COMMAND="$COMMAND 2>$paths_workdir/dump_memory_error.log"
    	;;

    *)
  		debug -d "memory_dump : Dump type not valid ($1)\n"
      echo     "memory_dump : Dump type not valid ($1)"
      return 255
  	  ;;
  esac  

	echo "---------- DUMP MEMORY ON DATE `date +"%b %d %H:%M:%S"` ----------"\
	  >>$paths_workdir/command_shots.log
  		  
  echo $COMMAND>>$paths_workdir/command_shots.log
  
  eval $COMMAND
  
	ret_val=$((`cat $paths_workdir/mdump_error.log | grep -c -i 'error'`))

	if [ $ret_val != "0" ]; then
		debug "FAIL.\n"
		# ------ EXIT CODE ------ #
		return 1
	fi

	debug "OK.\n"
	
	return 0
}
# ===============================================================================
# Erase helper - all, main, segment addess length
# ===============================================================================

erase () {
	# Find for any already started session
	check_debug_session
	local ret_val=$?

	if [ "$ret_val" -ne "0" ]; then
		debug -d "erase : session check failed.\n"
		return 3;
	fi

  case $1 in
    all)
  		debug -d "erase : Erase ALL target memory ... "
  
  		echo "---------- ERASE SHOT ON DATE `date +"%b %d %H:%M:%S"` ----------"\
  		  >>$paths_workdir/command_shots.log

      COMMAND="$paths_msp430gdb --batch"
  		COMMAND="$COMMAND -ex \"target remote localhost:2000\""
  	  COMMAND="$COMMAND -ex \"erase all \""
  	  COMMAND="$COMMAND >>$paths_workdir/command_shots.log"
  	  COMMAND="$COMMAND 2>$paths_workdir/erase_error.log"
  
      echo $COMMAND>>$paths_workdir/command_shots.log
      
      eval $COMMAND
      
  		local status=$?
  		if [ $status != "0" ]; then
  			debug "FAIL\n"
  			return 1
  		fi
  		debug "OK\n"
  		return 0
      ;;
    main)
      ;;
    segment)
# TOOOOOOOOOOOOOOOOOOOOOODOOOOOOOOOOOOOOOOOOOOOOO

#		ERASE_RANGE=$ERASE_RANGE" "$PARAM
#		echo "Cancello "`echo $ERASE_RANGE | cut -f2 -d' '`" byte partendo dall'indirizzo di memoria "`echo $ERASE_RANGE | cut -f1 -d' '`

      ;;
    *)
  		debug -d "erase : Erase type not valid ($1)\n"
      echo     "erase : Erase type not valid ($1)"
  	  ;;
  esac
    
	# ------ EXIT POINT------ unmanaged error #
	return 1
}
# ==============================================================================
# Verify the target firmware
# ==============================================================================

verify () {
  # Find for any already started session
  check_debug_session
  local ret_val=$?

  if [ "$ret_val" -ne "0" ]; then
    debug -d "verify : session check failed.\n"
    # ------ EXIT CODE ------ #
    return 3;
  fi

  mkdir $paths_sessiondir/down_buffer
  mkdir $paths_sessiondir/orig_buffer

  # Verify the complete cleanup of the cache directory
  if [ "`ls -l $paths_sessiondir/orig_buffer | grep -c '.*.hex'`" != "0" ] || 
     [ "`ls -l $paths_sessiondir/down_buffer | grep -c '.*.hex'`" != "0" ]; then
    debug -d "verify : cache directories not clean.\n"
    return 4
  fi

  # local defines
  local START="0x0000"
  local ORIG_START=$START
  local LENGTH="0x0000"
  local FILE=$ORIG_START".hex"
  local EXP_NEXT
  local TYPE
  local BATCH
  local DIFF_A
  local DIFF_B
  local COUNT
  local ORIG_CHUNKS
  local TARGET_CHUNKS

  # Check if the firmware file exists and its size is not zero
  if [ ! -s $paths_sessiondir/firmware.hex ]; then
    debug -d "verify : Firmware file error.\n"
    return 4;
  fi

  # Read from source file and split it in sectors
  debug -d "verify : Split source file ... "

  while read line; do
  #  debug -n "."
    # Obtain the expected address in the next line according to start address
    # and the specified row length
    EXP_NEXT=$(( $START + $LENGTH ))

    # Obtain key parameter from the current parsed line
    START="0x"${line:3:4}
    LENGTH="0x00"${line:1:2}
    TYPE=${line:7:2}

    # If the current row address is not as expected start a new sector
    if [ $EXP_NEXT != $(( $START )) ]; then
      # Prevent null data dump
      if [ $(( $ORIG_START )) != $EXP_NEXT ]; then
        BATCH="$BATCH -ex 'dump ihex memory $paths_sessiondir/down_buffer/$FILE $ORIG_START $EXP_NEXT' "
        cat $paths_sessiondir/orig_buffer/$FILE.tmp>$paths_sessiondir/orig_buffer/$FILE
        echo -e ":00000001FF\r">>$paths_sessiondir/orig_buffer/$FILE
        rm $paths_sessiondir/orig_buffer/$FILE".tmp"
      fi

      ORIG_START=$START
      FILE=$ORIG_START".hex"
     fi

    # Write only if there are datas
    if [ "$TYPE" = "00" ]; then
      echo $line>>$paths_sessiondir/orig_buffer/$FILE".tmp"
    fi
  done < $paths_sessiondir/firmware.hex


  local sector_list=`ls $paths_sessiondir/orig_buffer | grep '.*.hex'`
  local orig_chunks=`ls -l $paths_sessiondir/orig_buffer | grep -c '.*.hex'`
  local firmware_size=`cat $paths_sessiondir/firmware.conf | cut -d'	' -f 4`
  local orig_size
  local down_size

  # Check if firmware splitting has worked
  if [ "$orig_chunks" == "0" ];then
    debug "FAIL.\n"
    debug -d "verify : Result of firmware split is zero chunks.\n"
    # ------ EXIT CODE ------ #
    return 4
  fi

  # count the total size of the chunks files and compares with the size of
  # the local firmware file
  for file in $sector_list; do
    while read line; do
      orig_size=$(( orig_size+0x${line:1:2} ))
    done < $paths_sessiondir/orig_buffer/$file
  done

  if [ "$firmware_size" != "$orig_size" ]; then
    debug "FAIL.\n"
    debug -d "verify : Original firmware file size and splitted chunk "\
      "size differ.\n"
    debug -d "verify : Original firmware file size -> $firmware_size,"\
      "splitted chunk size -> $orig_size.\n"
      
    # ------ EXIT CODE ------ #
    return 4
  fi

  debug "OK.\n"
  debug -d "verify : Original firmware file size -> $firmware_size,"\
    "splitted chunk size -> $orig_size.\n"

  # Short report
  debug -d "verify : found $orig_chunks chunks.\n"
  for line in $sector_list; do
    debug -d "verify : $line\n"
  done

  # start verify
  debug -d "verify : Download firmware from target memory... "

  echo "---------- VERIFY ON DATE `date +"%b %d %H:%M:%S"` ----------"\
    >>$paths_sessiondir/command_shots.log

  COMMAND="$paths_msp430gdb --batch "\
  COMMAND=$COMMAND" -ex \"target remote localhost:2000\" "$BATCH\
  COMMAND=$COMMAND">>$paths_sessiondir/command_shots.log "\
  COMMAND=$COMMAND"2>$paths_sessiondir/verify_error.log"

  echo $COMMAND>>$paths_sessiondir/command_shots.log
  
  eval $COMMAND

  # Check if the corresponding chunk was downloaded from target memory
  local target_chunks=`ls -l $paths_sessiondir/down_buffer | grep -c '.*.hex'`
  if [ "$orig_chunks" != "$target_chunks" ];then
    debug "FAIL.\n"
    debug -d "verify : Original chunks number differ than downloaded"\
      "chunk number ($target_chunks instead of $orig_chunks).\n"
    
    # ------ EXIT CODE ------ #
    return 5;
  fi
  
  # count the total size of the downloaded chunks files and compares with the
  # size of the local firmware file
  for file in $sector_list; do
    while read line; do
      down_size=$(( down_size+0x${line:1:2} )) 
    done < $paths_sessiondir/down_buffer/$file
  done
  
  if [ "$firmware_size" != "$down_size" ]; then
    debug "FAIL.\n"
    debug -d "verify : Original firmware file size and downloaded "\
      "chunks size differ.\n"
    debug -d "verify : Original firmware file size -> $firmware_size,"\
      "downloaded chunk size -> $down_size.\n"
      
    # ------ EXIT CODE ------ #    
    return 5
  fi

  debug "OK.\n"
  debug -d "verify : Original firmware file size -> $firmware_size, "\
    "downloaded chunk size -> $down_size.\n"

  # Finally compares the hash of each pairs of serctors file, one obtained 
  # from the original file and other obtained from the microprocessor memory
  SECTORS_LIST=`ls $paths_sessiondir/orig_buffer | grep '.*.hex'`
  COUNT=0
  
  for FILE in $SECTORS_LIST; do
    debug -d "verify : Verify data chunk for file $FILE..."
    DIFF_A=`md5sum -b $paths_sessiondir/orig_buffer/$FILE | cut -f1 -d' '`
    DIFF_B=`md5sum -b $paths_sessiondir/down_buffer/$FILE | cut -f1 -d' '`
    if [ "$DIFF_A" != "$DIFF_B" ]; then
      debug "FAIL\n"
      echo "verify : chunk file '$FILE' didn't match."
      return 6
    else
      debug "OK\n"
      (( COUNT++))
    fi
  done

  debug -d "verify : All worked without any interruption.\n"
}
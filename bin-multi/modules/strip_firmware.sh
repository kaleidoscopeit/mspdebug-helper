# ==============================================================================
# Strip firmware in chunks
#
# returns :
#
# 0    -> strip firmware complete
# 1    -> firmware not selected
# ==============================================================================

strip_firmware () {
  rm -r $paths_sessiondir/firmware_stripped/
  mkdir $paths_sessiondir/firmware_stripped

  # local defines
  local START=0
  local SUM=0
  local ORIG_START=0
  local LENGTH=0
  local FILE=$ORIG_START
  local EXP_NEXT
  local TYPE
  local COUNT
  local OFFSET_HEADER=":020000020000FC"
  local NEXT_OFFSET_HEADER
  
  # Check if the firmware file exists and its size is not zero
  if [ ! -s $paths_sessiondir/firmware.hex -o \
       ! -s $paths_sessiondir/firmware.conf ] ; then
    debug -d "verify : Firmware not selected.\n"
    # ------ EXIT BREAKPOINT ------ #
    return 1
  fi
  
  # Read from source file and split it in sectors
  debug -d "stripdown_ihex : Split source file ... \n"

  while read line; do

  #  debug -n "."
    TYPE=${line:7:2}
    
    # Current line is a data line
    if [ "$TYPE" = "00" -o "$TYPE" = "01" ]; then

      # Obtain the expected address in the next line according to start address
      # and the specified row length of the previous line
      EXP_NEXT=$(( $START + $LENGTH ))
            
	    # Obtain key parameter from the current parsed line
      START=$(( 0x${line:3:4}+$SUM ))
      LENGTH=$(( 0x${line:1:2} ))
      DATA=${line:9:$(( $LENGTH*2 ))}
      
  	    # If the current row address is not subsequent the previous data close current copy and
      # start a new sector
      if [ $EXP_NEXT != $START ]; then
        # Prevent null data dump
        if [ $ORIG_START != $EXP_NEXT ]; then
          debug -d "stripdown_ihex : Chunk address : $FILE \n"
          # make the definitive file
          echo $OFFSET_HEADER>$paths_sessiondir/firmware_stripped/$FILE".hex"
          cat $paths_sessiondir/firmware_stripped/$FILE.tmp>>$paths_sessiondir/firmware_stripped/$FILE".hex"
          echo -e ":00000001FF\r">>$paths_sessiondir/firmware_stripped/$FILE".hex"
          
          # make a definition file for this chunk          
          echo `printf '0x%x 0x%x %d' $ORIG_START $EXP_NEXT $(( $EXP_NEXT - $ORIG_START ))` \
            `md5sum -b $paths_sessiondir/firmware_stripped/$FILE".data" | cut -f1 -d' '`\
            >$paths_sessiondir/firmware_stripped/$FILE".conf"

          
          # remove temporary file
          rm $paths_sessiondir/firmware_stripped/$FILE".tmp"
          
          # set the current global offset as the last found in the original file
          OFFSET_HEADER=$NEXT_OFFSET_HEADER
        fi
  
        ORIG_START=$START
        FILE=`printf '0x%x' $(( $ORIG_START ))`
      fi      
    fi
    
    if [ "$TYPE" = "00" ]; then
      # Write current row in the temporary file
      echo $line>>$paths_sessiondir/firmware_stripped/$FILE".tmp"
      echo -n $DATA>>$paths_sessiondir/firmware_stripped/$FILE".data"
    fi
    
    # parse current line as new data offset
    if [ "$TYPE" = "02" ]; then
      
      # Obtain key parameter from the current parsed line
      SUM="0x"${line:9:4}"0"
      if [ -s $FILE".tmp" ]; then
        echo $line>>$paths_sessiondir/firmware_stripped/$FILE".tmp"
      fi
      NEXT_OFFSET_HEADER=$line
    fi
    
  done < $paths_sessiondir/firmware.hex

  # ------ EXIT BREAKPOINT ------ #
  return 0
}
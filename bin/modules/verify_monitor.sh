# ===============================================================================
# Verify monitor
# ===============================================================================

verify_monitor () {
  local bound
  local progress=0
  local count=0
  local cprogress

  # get the size of the firmware file
  local size=`cat $paths_sessiondir/firmware.conf | cut -f 4`

  while read line; do

    # Find for the last 'bound' of gdebug
    bound=`echo $line | grep -c 'Bound to port'`
    if [ $bound -eq 1 -a $count -gt 0 ]; then
      break
    fi
        
    line=`echo $line | grep 'Verifying' | sed 's/^[\t ]*[0-9]*[\t ]*Verifying[\t ]*//g' | sed 's/bytes[. a-zA-Z0-9]*//g'`

    if [ -n "$line" ]; then
      progress=$(( progress+line ))
    fi

    (( count++ ))
  done < <(tac $paths_sessiondir/gdb.log)

  cprogress=$(( progress*100/size ))

  debug -d "verify_monitor : Progress to $cprogress% ($progress of $size)\n"

  return $cprogress
}
# ===============================================================================
# Memory dump monitor
# ===============================================================================

memory_dump_monitor () {
  local bound
  local progress=0
  local count=0
  local cprogress

  # get the size of the firmware file
  local size=`cat $paths_sessiondir"/memory_dump_size"`

  while read line; do
    line=`echo $line | grep 'Reading' | sed 's/^[\t ]*[0-9]*[\t ]*Reading[\t ]*//g' | sed 's/bytes[. a-zA-Z0-9]*//g'`
    
    if [ -n "$line" ]; then
      progress=$(( progress+line ))
    fi

    (( count++ ))
  done < $paths_sessiondir/memory_dump.log

  cprogress=$(( progress*100/size ))

  debug -d "memory_dump_monitor : Progress to $cprogress% ($progress of $size)\n"

  return $cprogress
}
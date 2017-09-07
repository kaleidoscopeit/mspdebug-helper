# =============================================================================
# Program monitor
# =============================================================================

program_monitor () {
  local bound
  local progress=0
  local count=0
  local cprogress

  # get the size of the firmware file
  local size=`cat $paths_sessiondir/firmware.conf | cut -f 4`

  while read line; do
    line=`echo $line | grep 'Writing' | sed 's/^[\t ]*[0-9]*[\t ]*Writing[\t ]*//g' | sed 's/bytes[. a-zA-Z0-9]*//g'`

    if [ -n "$line" ]; then
      progress=$(( progress+line ))
    fi

    (( count++ ))
  done < $paths_sessiondir/program.log

  cprogress=$(( progress*100/size ))

  debug -d "program_monitor : Progress to $cprogress% ($progress of $size)\n"

  return $cprogress
}
# ===============================================================================
# Verify monitor
# ===============================================================================

update_firmware_monitor () {
  local bound
  local progress=0
  local count=0

  # get the size of the firmware file
  local size=`cat $paths_workdir/fet_fw_update.log | cut -f 4`

  while read line; do

    # Find for the firs 'percent done' of the log
    percent=`echo $line | grep -c 'percent done'`
    if [ $percent -eq 1 ]; then
      progress=$(( `echo $line | cut -f1 -d' '` ))
      break
    fi
    
  done < <(tac $paths_workdir/fet_fw_update.log)
  
  anon_debug -d "update_firmware_monitor : Progress to $progress%\n"

  return $progress
}
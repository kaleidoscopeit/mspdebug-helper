#/bin/bash

# ===============================================================================
# Utility to control parallel port with pport ($1=set|reset, $2=pin number 2-9)
# ===============================================================================

control_parallel_pin () {

  if [ -z $paths_pport ]; then
    debug -d "control_parallel_pin : pport path not set.\n"
    return 3
  fi
  
  if [ ! -f $paths_pport ]; then
    debug -d "control_parallel_pin : pport executable not found.\n"
    return 3
  fi

  if [ ! -u $paths_pport -o ! -x $paths_pport ]; then
    debug -d "control_parallel_pin : pport wrong permissions.\n"
    return 3
  fi

  # Get current status
  local STATUS=`$paths_pport --status | grep $2 | grep -c -i 'Deactivated'`
  if [ $STATUS = "1" ]; then STATUS="reset"; else STATUS="set"; fi

  # toggle if necessary  
  if [ $STATUS != $1 ]; then eval $paths_pport -t $2; fi
  
  # verify toggle
  local STATUS=`$paths_pport --status | grep $2 | grep -c -i 'Deactivated'`
  if [ $STATUS = "1" ]; then STATUS="reset"; else STATUS="set"; fi
  
  echo $STATUS
  echo $1
  if [ $STATUS = $1 ]; then
    debug -d "control_parallel_pin : $1 pin $2.\n"
    return 1;
  else
    debug -d "control_parallel_pin : set pin $2 failed.\n"
    return 2
  fi
}
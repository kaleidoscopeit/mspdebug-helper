# ===============================================================================
# Determines the session startup based on a target device id
#
# returns :
#
# 0    -> target selected successfully
# 1    -> target name not supplied
# 2    -> error writing to the config file
#
# 10    -> session already started
# 12    -> a running session is not managed by this tool 
# ===============================================================================

select_target () {
  if [ -z "$1" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "select_target : Target name not supplied.\n"
    return 1
  fi

  # Check session status
  check_debug_session
  ret_val=$?

  if [ "$ret_val" -ne "1" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "select_target : Session already started. "\
      "Target selection is possible only before starting a session\n"
    return $(( ret_val+9 ))
  fi
  
  echo $1>$paths_sessiondir/target.conf

  if [ "`cat $paths_sessiondir/target.conf`" == "$1" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "select_target : Target selected -> $1.\n"
    return 0
  fi

  # ------ EXIT BREAKPOINT ------ #
  debug -d "select_target : Error writing config file.\n"
  return 2
}
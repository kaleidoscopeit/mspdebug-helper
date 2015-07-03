# =============================================================================
# Starts a debug session
#
# returns :
#
# 0    -> make command success
# 1    -> cannot find debug tool
# 2    -> write access denied to the debug tool
# =============================================================================

make_command () {
  # local variables declaration
  local DEVICE
  local paths_libmsp430=`dirname "$paths_libmsp430"`

  # Find if a debug tool exists depending by the given driver
  DEVICE=`find_device $driver`

  if [ -z "$DEVICE" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "make_command : Cannot find a debug tool.\n"
    return 1
  fi

  if [ ! -w "$DEVICE" ]; then
    # ------ EXIT BREAKPOINT ------ #
    debug -d "make_command : Write access denied to the debug tool. ($DEVICE)\n"
    return 2
  fi

  if [ $driver = "tilib" ]; then
    DEVICENAME=`echo $DEVICE | sed -e 's/\/dev\///g'`;
  else
    DEVICENAME=$DEVICE
  fi
  
  # set link type
  if [ $link = "jtag" ]; then link="-j"; else link=""; fi
  
  MSPDEBUG_CMD="LD_LIBRARY_PATH=$paths_libmsp430 $paths_mspdebug $driver "
  MSPDEBUG_CMD="$MSPDEBUG_CMD --allow-fw-update $link -d $DEVICENAME "
  
  # ------ EXIT BREAKPOINT ------ #
  debug -d "make_command :success ($MSPDEBUG_CMD)\n"
  return 0
}

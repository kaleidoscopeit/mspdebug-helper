# ==============================================================================
# Finds device and returns the serial port path at the stdout
# ==============================================================================

find_device () {
	for udi in `hal-find-by-capability --capability serial | sort`
	do
		local parent=`hal-get-property --udi ${udi} --key "info.parent" 2>/dev/null`
		local device=`hal-get-property --udi ${udi} --key "linux.device_file" 2>/dev/null`
		local vendor=`hal-get-property --udi ${parent} --key "usb.vendor_id" 2>/dev/null`
		local product=`hal-get-property --udi ${parent} --key "usb.product_id" 2>/dev/null`
		local jfet=`printf "%.4x:%.4x" "${vendor}" "${product}"`

    if [ $1 = "olimex" -a $jfet = "15ba:0031" ] ||
		   [ $1 = "tilib" -a $jfet = "2047:0010" ]
		then
			debug -d "find_device : Device path : "$device"\n"
			echo $device
			# ------ EXIT POINT------ Device found #
			return 0
		fi
	done

	# ------ EXIT POINT------ Device not found #
	debug -d "find_device : Device NOT found\n"
	return 1
}

# ==============================================================================
# Finds device and returns the serial port path at the stdout
# ==============================================================================

find_device () {


	# loop query for driver 'olymex'
	if [ $1 = "olimex" ]
	then

		for acms in `ls /dev/ttyACM* | sort`
		do
			# Query for MSP-FET430UIF
			local vendor=`udevadm info --query=property --name=$acms |\
				grep -c -i "ID_VENDOR_ID=15ba"`
			local product=`udevadm info --query=property --name=$acms |\
				grep -c -i "ID_MODEL_ID=0031"`

			if [ $vendor = "1" -a $product = "1" ]
			then
				local model=`udevadm info --query=property --name=$acms |\
					grep -i "ID_MODEL=" | cut -f2 -d'='`
				local path=`udevadm info --query=property --name=$acms |\
					grep -i "DEVNAME=" | cut -f2 -d'='`

				local devices=("${devices[@]}" $model)
				local paths=("${paths[@]}" $path)
			fi
		done
	
	fi

	# loop query for driver 'tilib'
	if [ $1 = "tilib" ]
	then

		for acms in `ls /dev/ttyACM* | sort`
		do

			# Query for MSP-FET430UIF
			local vendor=`udevadm info --query=property --name=$acms |\
				grep -c -i "ID_VENDOR_ID=2047"`
			local product=`udevadm info --query=property --name=$acms |\
				grep -c -i "ID_MODEL_ID=0010"`

			if [ $vendor = "1" -a $product = "1" ]
			then
				local model=`udevadm info --query=property --name=$acms |\
					grep -i "ID_MODEL=" | cut -f2 -d'='`
				local path=`udevadm info --query=property --name=$acms |\
					grep -i "DEVNAME=" | cut -f2 -d'='`

				local devices=("${devices[@]}" $model)
				local paths=("${paths[@]}" $path)
			fi
		done
	
	fi

	if [ ${#devices[@]} -gt 0 ]
	then
		debug -d "find_device : Found ${#devices[@]} devices.\n"
    rm $paths_workdir/devices
		for (( c=0; c<${#devices[@]}; c++ ))	
		do
			debug -d "find_device : Device $c, model : ${devices[$c]}, path : ${paths[$c]}\n"
      echo "devices[$c]=\"${devices[$c]}\"">>$paths_workdir/devices
      echo "paths[$c]=\"${paths[$c]}\"">>$paths_workdir/devices
		done

		# ------ EXIT POINT------ Device found #
		echo ${paths[0]}
		return 0

	else
		# ------ EXIT POINT------ Device not found #
		debug -d "find_device : Device NOT found\n"
		return 1

	fi





}

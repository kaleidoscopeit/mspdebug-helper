// Import 'mspprogrammer.js' in a way you like;

program_device={
	batch_count:0,
						
	start:function(){
		this.call_batch();
	},
		
	// Every function is asynchronous and for each one have to define a callback function handler
	// This is the way I prefer because it's possible to create a good clean stack

	batch:Array(
		// ---- CLOSE PREVIOUS SESSION ---- //
		function(){
			mspprogrammer.close_debug_session(function(data){
				// call next batch event
				program_device.call_batch();
			})
		},

		// ---- SELECT TARGET ---- //	
		function(){
			mspprogrammer.select_target([TARGET NAME],function(data){
				switch(data.result){
					// All done
					case 0:
						program_device.call_batch();
						break;

					// unhandled error
					default
						throw('unhandled error');
				}
			})
		},
			
		// ---- OPEN NEW SESSION ---- //
		function(){
			mspprogrammer.open_debug_session(function(data){
				switch(data.result){
					// debug tool not found
					case 4:
						throw('debug tool not found');
						break;

					// access to the debug tool denied
					case 5:
						throw('access to the debug tool denied')
						break;

					// target not found
					case 6:
						throw('target not found');
						break;

					// All done
					case 0:
						program_device.call_batch();
						break;

					// unhandled error
					default:
						throw('unhandled error');
				}
			})
		},

		// ---- SELECT FIRMWARE ---- //
		function(){
			mspprogrammer.select_firmware([FIRMWARE URL OR LOCATION],function(data){
				switch(data.result){
					// firmware file download error
					case 4:
						throw('firmware file download error');
						break;

					// All done
					case 0:
						program_device.call_batch();
						break;

					// unhandled error
					default:
						throw('unhandled error');
				}
			})
		},

		// ---- ERASE ALL ---- //
		function(){
			mspprogrammer.erase([TYPE], function(data){
				switch(data.result){
					// All done
					case 0:
						program_device.call_batch();
						break;

					// unhandled error
					default:
						throw('unhandled error');
				 }							
			})
		},
			
		// ---- PROGRAM TARGET ---- //
		function(){
			pmon=setInterval("mspprogrammer.program_monitor(function(data){YOUR MONITORING FUNCTION});",500);
			mspprogrammer.program(function(data){
				clearInterval(pmon);
				switch(data.result){
					// program error
					case 5:
						throw('program error');
						break;

					// All done
					case 0:
						program_device.call_batch();
						break;

					// unhandled error
					default:
						throw('unhandled error');	
				}
			})
		},
			
		// ---- VERIFY TARGET ---- //
		function(){
			pmon=setInterval("mspprogrammer.verify_monitor(function(data){YOUR MONITORING FUNCTION});",500);
			mspprogrammer.verify(function(data){
				clearInterval(pmon);
				switch(data.result){
					// firmware issue
					case 4:
						throw('firmware issue');
						break;

					// memory dump error
					case 5:
						throw('memory dump error');
						break;

					// verify error
					case 6:
						throw('verify error');
						break;

					// All done
					case 0:
						break;

					// unhandled error
					default:
						throw('unhandled error');
				}
			})
		}	
	),

	call_batch:function(){
		this.batch[this.batch_count]();
		this.batch_count++;
	}
};


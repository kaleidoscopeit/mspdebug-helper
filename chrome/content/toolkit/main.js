function showPanel(elem)
{
  document.getElementById("toolkitTabbox")
    .selectedPanel = document.getElementById(elem);
};

var toolkit = {
  init: function()
  {
    this.mainWindow = 
      window.QueryInterface(Components.interfaces.nsIInterfaceRequestor)
            .getInterface(Components.interfaces.nsIWebNavigation)
            .QueryInterface(Components.interfaces.nsIDocShellTreeItem)
            .rootTreeItem
            .QueryInterface(Components.interfaces.nsIInterfaceRequestor)
            .getInterface(Components.interfaces.nsIDOMWindow);
                       
    if(this.mainWindow == window)
      window.gBrowser = window.opener.getBrowser();
      
    window.mspdebughelper = this.mainWindow.gBrowser.mspdebughelper;

    // populate target popup-menu
    this.target_list = document.getElementById("target_list"); 
    this.fet_target  = {fet:[],olimex:[]};
    this.get_supported_targets();

    // grab status icons
    this.status_icons = {
      epv   : document.getElementById('status_ico_epv'),
      erase : document.getElementById('status_ico_erase'),
      prog  : document.getElementById('status_ico_prog'),
      ver   : document.getElementById('status_ico_ver'),
      mdump : document.getElementById('status_ico_mdump'),
      fwupd : document.getElementById('status_ico_fwupdate')
    };
 
    // status icons url's
    this.icon = {
      ok    : "chrome://mspdebughelper/skin/icons/ok.png",
      wait  : "chrome://mspdebughelper/skin/icons/wait.png",
      error : "chrome://mspdebughelper/skin/icons/error.png"
    };
 

  },

  get_supported_targets: function()
  {
    this.mainWindow.toolkit = this;

    mspdebughelper.callCommand('get_supported_targets', [], function(argv)
    {
      if(argv.result != '0') {
        console.log(argv);
        return;
      }
            
      var data = mspdebughelper.read('devices').split('\n');
      var cfamily;

      for(var i=0;i<data.length;i++) {
        if(data[i] == "Devices supported by FET driver:")
          cfamily = "fet";
          
        else if(data[i] == "Devices supported by Olimex FET driver:")
          cfamily = "olimex";
  
        else 
          toolkit.fet_target[cfamily] = 
            toolkit.fet_target[cfamily].concat(
              data[i].replace(/ +/g, ' ')
                     .replace(/(^[\s]+|[\s]+$)/g,'')
                     .split(' ')
            );
      }

      toolkit.fet_target['fet'].sort();
      toolkit.fet_target['olimex'].sort();
      
      for(let i=0;i<toolkit.fet_target.olimex.length;i++) {
        if(toolkit.fet_target.olimex[i] == "") continue;
        let new_item = document.createElement("menuitem");
        toolkit.target_list.appendChild(new_item);
        new_item.value = new_item.label = toolkit.fet_target.olimex[i];
     };
    });
  },

  fill_epv_console: function(target)
  {
    let data = mspdebughelper.read(target);
    let target_console = document.getElementById(target+'Log');
    target_console.value = data;
    let pos = target_console.value.length;
    target_console.selectionStart = pos;
    target_console.selectionEnd = pos;
  },

  fill_dump_console: function(target)
  {	  
    let data = mspdebughelper.read("/current/dump_memory/" + target + ".hex");
    let target_console = document.getElementById("dumpConsole");
    target_console.value = data;
    let pos = target_console.value.length;
    target_console.selectionStart = pos;
    target_console.selectionEnd = pos;
  },
  
  enable_range_fields: function(){
    let dump_type = document.getElementById('dump_type');
    let segmfrom  = document.getElementById('segmfrom');
    let segmto    = document.getElementById('segmto');
    
    if(dump_type.value == "segment")
      segmfrom.disabled = segmto.disabled = false;
    else 
      segmfrom.disabled = segmto.disabled = true;
  },
  
  set_progress: function(n){
	let progress    = document.getElementById('progress');
	progress.value = n;
  }
};

/*******************************************************************
 * EPV
 *******************************************************************/

toolkit.epv = {
  batch_count:0,
            
  start:function(){
    toolkit.hexfile = document.getElementById('hexfile').value;
    toolkit.target  = document.getElementById('target').value;
    toolkit.erase   = document.getElementById('erase').value;

    toolkit.status_icons.epv.src =
    toolkit.status_icons.erase.src =
    toolkit.status_icons.prog.src =
    toolkit.status_icons.ver.src =
    toolkit.icon.wait;
      
    toolkit.cmon=setInterval("toolkit.fill_epv_console('gdb')",1000);
    this.batch_count = 0;        
    this.call_batch();
  },
    
  // Every function is asynchronous and for each one have to define a callback function handler
  // This is the way I prefer because it's possible to create a good clean stack

  batch:Array(
    // ---- START A NEW SESSION ---- //
    function(){
      toolkit.set_progress(0);
      mspdebughelper.callCommand('new_session',['kill'],function(data) {
        switch(data.result){
          // All done
          case 0:
            toolkit.epv.call_batch();
            break;
          
          // unhandled exception
          default :
          	let errors=[];
	        errors[10]='local session is active/still active';
	    	errors[12]='foreign session is active/still active';
	    	toolkit.epv.except('new_session: ' + errors[data.result]);
        }
      })
    },
    
    // ---- SELECT TARGET ---- //
    function(){
      mspdebughelper.callCommand('select_target', [toolkit.target], function(data){
        switch(data.result){
          // All done
          case 0:
        	toolkit.set_progress(14);
            toolkit.epv.call_batch();
            break;

          // unhandled exception
          default :
        	let errors=[];
	        errors[1]='target name not supplied';
	        errors[2]='error writing to the config file';
	        errors[10]='session already started';
	    	errors[12]='a running session is not managed by this tool';
            toolkit.epv.except('select_target: ' + errors[data.result]);
        }
      });
    },
    
    // ---- OPEN DEBUG SESSION ---- //  
    function(){
      mspdebughelper.callCommand('open_debug_session', [], function(data){
        switch(data.result){
          // All done
          case 0:
        	toolkit.set_progress(14);
            toolkit.epv.call_batch();
            break;

          // unhandled exception
          default :
        	let errors=[];
            errors[1]='wrong target/target not found';
            errors[2]='debug tool issue';
            errors[10]='session already started';
        	errors[12]='a running session is not managed by this tool';
        	errors[255]='unmanaged error';

            toolkit.epv.except('open_debug_session: ' + errors[data.result]);
        }
      });
    },
    
    // ---- SELECT FIRMWARE ---- //
    function(){
     
      mspdebughelper.callCommand('select_firmware', [toolkit.hexfile], function(data){
        switch(data.result){
          // All done
          case 0:
        	toolkit.set_progress(20);        	
            toolkit.epv.call_batch();
            break;

          default :    	  
          	let errors=[];
            errors[1]='remove firmware cache failed';
            errors[2]='get firmware from source location failed';
            errors[10]='session not started';
            errors[11]='a running session is not managed by this tool ';
            errors[255]='unmanaged error';

            toolkit.epv.except('select_firmware: ' + errors[data.result]);
        }
      });
    },

    // ---- PROGRAM TARGET ---- //
    function(){
      toolkit.status_icons.erase.src = toolkit.icon.ok;
      toolkit.pmon=setInterval("mspdebughelper.callCommand('program_monitor',[],"+
        "function(data){if(toolkit.pmon)toolkit.set_progress(20+data.result*0.4)});",500);
        
      mspdebughelper.callCommand('program', [toolkit.erase], function(data){
        switch(data.result){
        // All done
        case 0:
          toolkit.set_progress(60);
          toolkit.status_icons.prog.src = toolkit.icon.ok;
          clearInterval(toolkit.pmon);
          toolkit.epv.call_batch();
          break;

        default :
          let errors=[];
          errors[1]='program failed';
          errors[2]='firmware not selected';
          errors[10]='session not started';
          errors[11]='a running session is not managed by this tool ';

          toolkit.epv.except('program: ' + errors[data.result]);
        }
      });
    },
      
    // ---- VERIFY TARGET ---- //
    function(){
        toolkit.pmon=setInterval("mspdebughelper.callCommand('verify_monitor',[],"+
                "function(data){if(toolkit.pmon)toolkit.set_progress(60+data.result*0.4)});",500);
                
	  mspdebughelper.callCommand('verify', [], function(data){
	    switch(data.result){
	      // All done
	      case 0:
	        toolkit.set_progress(100);
	        clearInterval(toolkit.pmon);
	        clearInterval(toolkit.cmon);
	        toolkit.epv.call_batch();
	        toolkit.fill_epv_console('main');
	        break;

	      default :
	        let errors=[];
	        errors[1]='verify failed';
	        errors[2]='firmware not selected';
	        errors[10]='session not started';
	        errors[11]='a running session is not managed by this tool ';

	        toolkit.epv.except('verify: ' + errors[data.result]);
	    }
      });
    },
    
    // ---- CLOSE DEBUG SESSION ---- //  
    function(){
      mspdebughelper.callCommand('close_debug_session', [], function(data){
        switch(data.result){
          // All done
          case 0:
        	toolkit.set_progress(100);
	        toolkit.status_icons.epv.src = toolkit.icon.ok;
	        toolkit.status_icons.ver.src = toolkit.icon.ok;
            break;

          // unhandled exception
          default :
        	let errors=[];
            errors[1]='close session failed';
          	errors[10]='session not started';
          	errors[11]='a foreign session is currently running';

            toolkit.epv.except('close_debug_session: ' + errors[data.result]);
        }
      });
    }    
  ),

  call_batch:function() {
    this.batch[this.batch_count]();
    this.batch_count++;
  },

  except:function(arg) {
    if(toolkit.status_icons.erase.src == toolkit.icon.wait )
      toolkit.status_icons.erase.src = toolkit.icon.error;

    if(toolkit.status_icons.prog.src == toolkit.icon.wait )
      toolkit.status_icons.prog.src = toolkit.icon.error;

    if(toolkit.status_icons.ver.src == toolkit.icon.wait )
      toolkit.status_icons.ver.src = toolkit.icon.error;

    toolkit.status_icons.epv.src = toolkit.icon.error;

    clearInterval(toolkit.pmon);
    clearInterval(toolkit.cmon);
    toolkit.fill_epv_console('gdb');
    mspdebughelper.callCommand('close_debug_session', [], function(data){});
    
    throw(arg);
  }
}


/*******************************************************************
 * VERIFY
 *******************************************************************/

toolkit.ver = {
  batch_count:0,
            
  start:function(){
    toolkit.hexfile = document.getElementById('hexfile').value;
    toolkit.target  = document.getElementById('target').value;
    toolkit.erase   = document.getElementById('erase').value;

    toolkit.status_icons.ver.src =
    toolkit.icon.wait;
      
    toolkit.pmon=setInterval("toolkit.fill_epv_console('main')",1000);
    this.batch_count = 0;        
    this.call_batch();
  },
    
  // Every function is asynchronous and for each one have to define a callback function handler
  // This is the way I prefer because it's possible to create a good clean stack

  batch:Array(
    // ---- START A NEW SESSION ---- //
    function(){
      toolkit.set_progress(0);
      mspdebughelper.callCommand('new_session',['kill'],function(data) {
        switch(data.result){
          // All done
          case 0:
            toolkit.ver.call_batch();
            break;
          
          // unhandled exception
          default :
            let errors=[];
	        errors[10]='local session is active/still active';
	    	errors[12]='foreign session is active/still active';
	    	toolkit.ver.except('new_session: ' + errors[data.result]);
        }
      })
    },
    
    // ---- SELECT TARGET ---- //  
    function(){
      mspdebughelper.callCommand('select_target', ['auto'], function(data){
        switch(data.result){
          // All done
          case 0:
        	toolkit.set_progress(10);
            toolkit.ver.call_batch();
            break;

          // unhandled exception
          default :
        	let errors=[];     
            errors[1]='target name not supplied';
            errors[2]='error writing to the config file';
            errors[10]='session already started';
        	errors[12]='a running session is not managed by this tool';
        	
            toolkit.ver.except('select_target: ' + errors[data.result]);
        }
      });
    },

    // ---- OPEN DEBUG SESSION ---- //  
    function(){
      mspdebughelper.callCommand('open_debug_session', [], function(data){
        switch(data.result){
          // All done
          case 0:
        	toolkit.set_progress(10);
            toolkit.ver.call_batch();
            break;

          // unhandled exception
          default :
        	let errors=[];
          	errors[1]='wrong target/target not found';
          	errors[2]='debug tool issue';
          	errors[10]='session already started';
          	errors[12]='a running session is not managed by this tool';
          	errors[255]='unmanaged error';

            toolkit.ver.except('open_debug_session: ' + errors[data.result]);
        }
      });
    },
      
    // ---- SELECT FIRMWARE ---- //
    function(){
     
      mspdebughelper.callCommand('select_firmware', [toolkit.hexfile], function(data){
        switch(data.result){
          // All done
          case 0:
        	toolkit.set_progress(20);        	
            toolkit.ver.call_batch();
            break;

          default :    	  
          	let errors=[];
          	errors[1]='remove firmware cache failed';
          	errors[2]='get firmware from source location failed';
          	errors[10]='session not started';
          	errors[11]='a running session is not managed by this tool ';
          	errors[255]='unmanaged error';

            toolkit.ver.except('select_firmware: ' + errors[data.result]);
        }
      });
    },

    // ---- VERIFY TARGET ---- //
    function(){
        toolkit.pmon=setInterval("mspdebughelper.callCommand('verify_monitor',[],"+
                "function(data){if(toolkit.pmon)toolkit.set_progress(60+data.result*0.4)});",500);
                
	  mspdebughelper.callCommand('verify', [], function(data){
	    switch(data.result){
	      // All done
	      case 0:
	        toolkit.set_progress(100);
	        clearInterval(toolkit.pmon);
	        toolkit.ver.call_batch();
	        toolkit.fill_epv_console('main');
	        break;

	      default :
	        let errors=[];
	        errors[1]='verify failed';
	        errors[2]='firmware not selected';
	        errors[10]='session not started';
	        errors[11]='a running session is not managed by this tool ';
	
	        toolkit.ver.except('verify: ' + errors[data.result]);
	    }
      });
    },
    
    // ---- CLOSE DEBUG SESSION ---- //  
    function(){
      mspdebughelper.callCommand('close_debug_session', [], function(data){
        switch(data.result){
          // All done
          case 0:
        	toolkit.set_progress(100);
        	toolkit.status_icons.ver.src = toolkit.icon.ok;
            break;

          // unhandled exception
          default :
        	let errors=[];
         	errors[1]='close session failed';
        	errors[10]='session not started';
        	errors[11]='a foreign session is currently running';
        	
            toolkit.epv.except('close_debug_session: ' + errors[data.result]);
        }
      });
    }
  ),

  call_batch:function() {
    this.batch[this.batch_count]();
    this.batch_count++;
  },

  except:function(arg) {
    if(toolkit.status_icons.erase.src == toolkit.icon.wait )
      toolkit.status_icons.erase.src = toolkit.icon.error;

    if(toolkit.status_icons.prog.src == toolkit.icon.wait )
      toolkit.status_icons.prog.src = toolkit.icon.error;

    if(toolkit.status_icons.ver.src == toolkit.icon.wait )
      toolkit.status_icons.ver.src = toolkit.icon.error;

    toolkit.status_icons.epv.src = toolkit.icon.error;

    clearInterval(toolkit.pmon);
    toolkit.fill_epc_console('main');        
    throw(arg);
  }
}


/*******************************************************************
 * MEMORY DUMP
 *******************************************************************/
toolkit.mdump = {
  batch_count:0,
            
  start:function(){
    toolkit.status_icons.mdump.src = toolkit.icon.wait;
    
    toolkit.dump_type= document.getElementById('dump_type').value;
   // toolkit.pmon  = setInterval("toolkit.fill_dump_console('main')",1000);
    this.batch_count = 0;        
    this.call_batch();
  },
    
  // Every function is asynchronous and for each one have to define a callback 
  // function handler which calls the next operation.
  // This is the way I prefer because it's possible to create a good clean stack

  batch:Array(
    // ---- START A NEW SESSION ---- //
    function(){
      toolkit.set_progress(0);
      mspdebughelper.callCommand('new_session',['kill'],function(data) {
        switch(data.result){
          // All done
          case 0:
            toolkit.mdump.call_batch();
            break;
          
          // unhandled exception
          default :
            let errors=[];
	        errors[10]='local session is active/still active';
	    	errors[12]='foreign session is active/still active';
	    	toolkit.mdump.except('new_session: ' + errors[data.result]);
        }
      })
    },
    
    // ---- SELECT TARGET ---- //  
    function(){
      mspdebughelper.callCommand('select_target', ['auto'], function(data){
        switch(data.result){
          // All done
          case 0:
        	toolkit.set_progress(10);
            toolkit.mdump.call_batch();
            break;

          // unhandled exception
          default :
        	let errors=[];     
            errors[1]='target name not supplied';
            errors[2]='error writing to the config file';
            errors[10]='session already started';
        	errors[12]='a running session is not managed by this tool';

            toolkit.mdump.except('select_target: ' + errors[data.result]);
        }
      });
    },

    // ---- OPEN DEBUG SESSION ---- //  
    function(){
      mspdebughelper.callCommand('open_debug_session', [], function(data){
        switch(data.result){
          // All done
          case 0:
        	toolkit.set_progress(10);
            toolkit.mdump.call_batch();
            break;

          // unhandled exception
          default :
        	let errors=[];
          	errors[1]='wrong target/target not found';
          	errors[2]='debug tool issue';
          	errors[10]='session already started';
          	errors[12]='a running session is not managed by this tool';
          	errors[255]='unmanaged error';

            toolkit.mdump.except('open_debug_session: ' + errors[data.result]);
        }
      });
    },
    
    // ---- DUMP MEMORY ---- //
    function(){
      toolkit.pmon=setInterval("mspdebughelper.callCommand('memory_dump_monitor',[],"+
        "function(data){if(toolkit.pmon)toolkit.set_progress(10+data.result*0.9)});",500);

      let segmfrom = document.getElementById('segmfrom').value;
	  let segmto   = document.getElementById('segmto').value;
	  
      mspdebughelper.callCommand('memory_dump',
    		  [toolkit.dump_type, segmfrom, segmto], function(data){
        switch(data.result){
          // All done
          case 0:
            clearInterval(toolkit.pmon);
            toolkit.mdump.call_batch();
            let target;
            switch(toolkit.dump_type) {
              case 'all'  : target = "all";  break;
              case 'main' : target = "main"; break;
              case 'info' : target = "info"; break;
              case 'segment' : target = segmfrom ; break;
            }
            
            toolkit.fill_dump_console(target);
            break;

          // unhandled exception
          default:
        	let errors=[];
        	errors[1]='dump memory failed';
            errors[2]='wrong arguments';
            errors[10]='session not started';
            errors[11]='a foreign session is currently running';

            toolkit.mdump.except('memory_dump: ' + errors[data.result] + data.result);
        }
      });
    },
 
    // ---- CLOSE DEBUG SESSION ---- //  
    function(){
      mspdebughelper.callCommand('close_debug_session', [], function(data){
        switch(data.result){
          // All done
          case 0:
        	toolkit.set_progress(100);
        	toolkit.status_icons.mdump.src = toolkit.icon.ok;
            break;

          // unhandled exception
          default :
        	let errors=[];
          	errors[1]='close session failed';
        	errors[10]='session not started';
        	errors[11]='a foreign session is currently running';

            toolkit.mdump.except('close_debug_session: ' + errors[data.result]);
        }
      });
    }
  ),

  call_batch:function() {
    this.batch[this.batch_count]();
    this.batch_count++;
  },

  except:function(arg) {
    toolkit.status_icons.mdump.src = toolkit.icon.error;
    clearInterval(toolkit.pmon);
    toolkit.fill_dump_console('main');        
    throw(arg);
  }
};


/*******************************************************************
 * UPDATE FIRMWARE
 *******************************************************************/
toolkit.fwupdate = {
  batch_count:0,
            
  start:function(){
    toolkit.status_icons.fwupd.src = toolkit.icon.wait;

    this.batch_count = 0;        
    this.call_batch();
  },
    
  // Every function is asynchronous and for each one have to define a callback 
  // function handler which calls the next operation.
  // This is the way I prefer because it's possible to create a good clean stack

  batch:Array(
    // ---- UPDATE FIRMWARE ---- //
    function(){
      toolkit.pmon=setInterval("mspdebughelper.callCommand('update_firmware_monitor',[],"+
        "function(data){if(toolkit.pmon)toolkit.set_progress(data.result)});",500);
        
      mspdebughelper.callCommand('update_firmware', [], function(data){
        switch(data.result){
          // All done
          case 0:
            clearInterval(toolkit.pmon);
            toolkit.set_progress(100);
            toolkit.status_icons.fwupd.src = toolkit.icon.ok;
            break;

          // unhandled exception
          default:
        	let errors=[];
        	errors[1]='update error';
            errors[2]='debug tool issue';
            errors[10]='session already started';
            errors[11]='a running session is not managed by this tool';

            toolkit.fwupdate.except('update_firmware : ' + errors[data.result] + data.result);
        }
      });
    }
  ),

  call_batch:function() {
    this.batch[this.batch_count]();
    this.batch_count++;
  },

  except:function(arg) {
    toolkit.status_icons.fwupd.src = toolkit.icon.error;
    clearInterval(toolkit.pmon);
    throw(arg);
  }
};

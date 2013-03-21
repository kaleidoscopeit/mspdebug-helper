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
      mdump : document.getElementById('status_ico_mdump')
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

    mspdebughelper.callCommand('get_supported_targets', [], function()
    {
      let data = mspdebughelper.read('gdb').split('\n');
      let cfamily;

      for(let i=0;i<data.length;i++) {
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

  fill_console: function(target)
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
    let data = mspdebughelper.read("/dump_memory/" + target + ".hex");
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
  }
};

/*******************************************************************
 *
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
      
    toolkit.pmon=setInterval("toolkit.fill_console('main')",1000);
    this.batch_count = 0;        
    this.call_batch();
  },
    
  // Every function is asynchronous and for each one have to define a callback function handler
  // This is the way I prefer because it's possible to create a good clean stack

  batch:Array(
    // ---- CLOSE PREVIOUS SESSION ---- //
    function(){
      mspdebughelper.callCommand('close_debug_session', [], function(data){
        // call next batch event
        toolkit.epv.call_batch();
      });
    },
    
    // ---- CLEAN PREVIOUS SESSION ---- //
    function(){
      mspdebughelper.callCommand('clean_debug_session', [], function(data){
        // call next batch event
        toolkit.epv.call_batch();
      });
    },
    
    // ---- SELECT TARGET ---- //  
    function(){
      mspdebughelper.callCommand('select_target', [toolkit.target], function(data){
        switch(data.result){
          // All done
          case 0:
            toolkit.epv.call_batch();
            break;

          // unhandled exception
          default :
            toolkit.epv.except('select_target: unhandled exception');
        }
      });
    },
      
    // ---- OPEN NEW SESSION ---- //
    function(){
      mspdebughelper.callCommand('open_debug_session', [], function(data){
        switch(data.result){
          // debug tool not found
          case 4:
            toolkit.epv.except('open_debug_session: debug tool not found');
            break;

          // access to the debug tool denied
          case 5:
            toolkit.epv.except('open_debug_session: access to the debug tool denied');
            break;

          // target not found
          case 6:
            toolkit.epv.except('open_debug_session: target not found');
            break;

          // All done
          case 0:
            toolkit.epv.call_batch();
            break;

          // unhandled exception
          default :
            toolkit.epv.except('open_debug_session: unhandled exception');
        }
      });
    },

    // ---- SELECT FIRMWARE ---- //
    function(){
      mspdebughelper.callCommand('select_firmware', [toolkit.hexfile], function(data){
        switch(data.result){
          // firmware file download error
          case 4:
            toolkit.epv.except('select_firmware: firmware file download error');
            break;

          // All done
          case 0:
            toolkit.epv.call_batch();
            break;

          // unhandled exception
          default:
            toolkit.epv.except('select_firmware: unhandled exception');
        }
      });
    },

    // ---- ERASE ALL ---- //
    function(){
      mspdebughelper.callCommand('erase', [toolkit.erase], function(data){
        switch(data.result){
          // All done
          case 0:
            toolkit.status_icons.erase.src = toolkit.icon.ok;
            toolkit.epv.call_batch();
            break;

          // unhandled exception
          default :
            toolkit.epv.except('erase: unhandled exception');
         }              
      });
    },
      
    // ---- PROGRAM TARGET ---- //
    function(){
      mspdebughelper.callCommand('program', [], function(data){
        switch(data.result){
          // program error
          case 5:
            toolkit.epv.except('program: program error');
            break;

          // All done
          case 0:
            toolkit.status_icons.prog.src = toolkit.icon.ok;
            toolkit.epv.call_batch();
            break;

          // unhandled exception
          default :
            toolkit.epv.except('program: unhandled exception');  
        }
      });
    },
      
    // ---- VERIFY TARGET ---- //
    function(){
      mspdebughelper.callCommand('verify', [], function(data){
        switch(data.result){
          // firmware issue
          case 4:
            toolkit.epv.except('verify: firmware issue');
            break;

          // memory dump error
          case 5:
            toolkit.epv.except('verify: memory dump error');
            break;

          // verify error
          case 6:
            toolkit.epv.except('verify: verify error');
            break;

          // All done
          case 0:
            toolkit.status_icons.ver.src = toolkit.icon.ok;
            toolkit.epv.call_batch();
            break;

          // unhandled exception
          default:
            toolkit.epv.except('verify: unhandled exception');
        }
      });
    },
 
    // ---- CLOSE SESSION ---- //
    function(){
      mspdebughelper.callCommand('close_debug_session', [], function(data){
        // stops monitor
        toolkit.status_icons.epv.src = toolkit.icon.ok;
        clearInterval(toolkit.pmon);
        toolkit.fill_console('main');
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

    else if(toolkit.status_icons.prog.src == toolkit.icon.wait )
      toolkit.status_icons.prog.src = toolkit.icon.error;

    else if(toolkit.status_icons.ver.src == toolkit.icon.wait )
      toolkit.status_icons.ver.src = toolkit.icon.error;

    toolkit.status_icons.epv.src = toolkit.icon.error;

    clearInterval(toolkit.pmon);
    toolkit.fill_console('main');        
    throw(arg);
  }
}

/*******************************************************************
 *
 *******************************************************************/
toolkit.mdump = {
  batch_count:0,
            
  start:function(){
    toolkit.status_icons.mdump.src = toolkit.icon.wait;
    
    toolkit.dump_type= document.getElementById('dump_type').value;
    toolkit.pmon  = setInterval("toolkit.fill_console('main')",1000);
    this.batch_count = 0;        
    this.call_batch();
  },
    
  // Every function is asynchronous and for each one have to define a callback function handler
  // This is the way I prefer because it's possible to create a good clean stack

  batch:Array(
    // ---- CLOSE PREVIOUS SESSION ---- //
    function(){
      mspdebughelper.callCommand('close_debug_session', [], function(data){
        // call next batch event
        toolkit.mdump.call_batch();
      });
    },
    
    // ---- CLEAN PREVIOUS SESSION ---- //
    function(){
      mspdebughelper.callCommand('clean_debug_session', [], function(data){
        // call next batch event
        toolkit.mdump.call_batch();
      });
    },

    // ---- SELECT TARGET ---- //  
    function(){
      mspdebughelper.callCommand('select_target', ['auto'], function(data){
        switch(data.result){
          // All done
          case 0:
            toolkit.mdump.call_batch();
            break;

          // unhandled exception
          default :
            toolkit.mdump.except('select_target: unhandled exception');
        }
      });
    },
        
    // ---- OPEN NEW SESSION ---- //
    function(){
      mspdebughelper.callCommand('open_debug_session', [], function(data){
        switch(data.result){
          // debug tool not found
          case 4:
            toolkit.mdump.except('open_debug_session: debug tool not found');
            break;

          // access to the debug tool denied
          case 5:
            toolkit.mdump.except('open_debug_session: access to the debug tool denied');
            break;

          // target not found
          case 6:
            toolkit.mdump.except('open_debug_session: target not found');
            break;

          // All done
          case 0:
            toolkit.mdump.call_batch();
            break;

          // unhandled exception
          default :
            toolkit.mdump.except('open_debug_session: unhandled exception');
        }
      });
    },

     
     
    // ---- VERIFY TARGET ---- //
    function(){
      mspdebughelper.callCommand('memory_dump', [toolkit.dump_type], function(data){
        switch(data.result){
          // firmware issue
          case 1:
            toolkit.mdump.except('memory_dump: firmware issue');
            break;

          // memory dump error
          case 5:
            toolkit.mdump.except('memory_dump: memory dump error');
            break;

          // verify error
          case 6:
            toolkit.mdump.except('memory_dump: verify error');
            break;

          // All done
          case 0:
            toolkit.status_icons.ver.src = toolkit.icon.ok;
            toolkit.mdump.call_batch();
            break;

          // unhandled exception
          default:
            toolkit.mdump.except('memory_dump: unhandled exception');
        }
      });
    },
 
    // ---- CLOSE SESSION ---- //
    function(){
      mspdebughelper.callCommand('close_debug_session', [], function(data){
        // stops monitor
            toolkit.status_icons.mdump.src = toolkit.icon.ok;
        clearInterval(toolkit.pmon);
        let target;
        switch(toolkit.dump_type) {
          case 'all'  : target = "all";  break;
          case 'main' : target = "main"; break;
          case 'info' : target = "info"; break;
            
        }
        toolkit.fill_dump_console(target);
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
    toolkit.fill_console('main');        
    throw(arg);
  }
};

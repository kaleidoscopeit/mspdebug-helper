function showPanel(elem)
{
  document.getElementById("toolkitTabbox")
    .selectedPanel = document.getElementById(elem);
};

var toolkit = {
  init: function()
  {
    this.mainWindow = window.QueryInterface(Components.interfaces.nsIInterfaceRequestor)
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
        new_item    = document.createElement("menuitem");
        toolkit.target_list.appendChild(new_item);
        new_item.value = new_item.label = toolkit.fet_target.olimex[i];
     }
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
};


toolkit.epv = {
  batch_count:0,
            
  start:function(){
    toolkit.hexfile = document.getElementById('hexfile').value;
    toolkit.target  = document.getElementById('target').value;
    toolkit.erase   = document.getElementById('erase').value;
    toolkit.console = document.getElementById('console');

    toolkit.pmon=setInterval("toolkit.fill_console('main')",1000);
    this.batch_count = 0;        
    this.call_batch();
  },
    
  // Every function is asynchronous and for each one have to define a callback function handler
  // This is the way I prefer because it's possible to create a good clean stack

  batch:Array(
    // ---- CLEAN PREVIOUS SESSION ---- //
    function(){
      mspdebughelper.callCommand('clean_debug_session', [], function(data){
        // call next batch event
        toolkit.epv.call_batch();
      })
    },
    
    // ---- CLOSE PREVIOUS SESSION ---- //
    function(){
      mspdebughelper.callCommand('close_debug_session', [], function(data){
        // call next batch event
        toolkit.epv.call_batch();
      })
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
            throw('select_target: unhandled exception');
        }
      })
    },
      
    // ---- OPEN NEW SESSION ---- //
    function(){
      mspdebughelper.callCommand('open_debug_session', [], function(data){
        switch(data.result){
          // debug tool not found
          case 4:
            throw('open_debug_session: debug tool not found');
            break;

          // access to the debug tool denied
          case 5:
            throw('open_debug_session: access to the debug tool denied')
            break;

          // target not found
          case 6:
            throw('open_debug_session: target not found');
            break;

          // All done
          case 0:
            toolkit.epv.call_batch();
            break;

          // unhandled exception
          default :
            throw('open_debug_session: unhandled exception');
        }
      })
    },

    // ---- SELECT FIRMWARE ---- //
    function(){
      mspdebughelper.callCommand('select_firmware', [toolkit.hexfile], function(data){
        switch(data.result){
          // firmware file download error
          case 4:
            throw('select_firmware: firmware file download error');
            break;

          // All done
          case 0:
            toolkit.epv.call_batch();
            break;

          // unhandled exception
          default:
            throw('select_firmware: unhandled exception');
        }
      })
    },

    // ---- ERASE ALL ---- //
    function(){
      mspdebughelper.callCommand('erase', [toolkit.erase], function(data){
        switch(data.result){
          // All done
          case 0:
            toolkit.epv.call_batch();
            break;

          // unhandled exception
          default :
            throw('erase: unhandled exception');
         }              
      })
    },
      
    // ---- PROGRAM TARGET ---- //
    function(){
      mspdebughelper.callCommand('program', [], function(data){
        switch(data.result){
          // program error
          case 5:
            throw('program: program error');
            break;

          // All done
          case 0:
            toolkit.epv.call_batch();
            break;

          // unhandled exception
          default :
            throw('program: unhandled exception');  
        }
      })
    },
      
    // ---- VERIFY TARGET ---- //
    function(){
      mspdebughelper.callCommand('verify', [], function(data){
        switch(data.result){
          // firmware issue
          case 4:
            throw('verify: firmware issue');
            break;

          // memory dump error
          case 5:
            throw('verify: memory dump error');
            break;

          // verify error
          case 6:
            throw('verify: verify error');
            break;

          // All done
          case 0:
            toolkit.epv.call_batch();
            break;

          // unhandled exception
          default:
            throw('verify: unhandled exception');
        }
      })
    },
 
    // ---- CLOSE SESSION ---- //
    function(){
      mspdebughelper.callCommand('close_debug_session', [], function(data){
        // stops monitor
        clearInterval(toolkit.pmon);
        toolkit.fill_console('main');
      })
    }    
  ),

  call_batch:function(){
    this.batch[this.batch_count]();
    this.batch_count++;
  }
}

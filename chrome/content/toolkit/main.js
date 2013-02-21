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

    // populate device popup-menu
    this.device_list = document.getElementById("device_list"); 
    this.get_supported_devices();
  },

  get_supported_devices: function()
  {
    this.mainWindow.toolkit = this;

    mspdebughelper.callCommand('get_supported_devices', [], function()
    {
      let data            = mspdebughelper.read('gdb').split('\n');
      toolkit.fet_devices = {fet:[],olimex:[]};
      let cfamily;

      for(let i=0;i<data.length;i++) {

        if(data[i] == "Devices supported by FET driver:")
          cfamily = "fet";
          
        else if(data[i] == "Devices supported by Olimex FET driver:")
          cfamily = "olimex";
  
        else 
          toolkit.fet_devices[cfamily] = 
            toolkit.fet_devices[cfamily].concat(
              data[i].replace(/ +/g, ' ')
                     .replace(/(^[\s]+|[\s]+$)/g,'')
                     .split(' ')
            );
      }

      toolkit.fet_devices['fet'].sort();
      toolkit.fet_devices['olimex'].sort();
      
      for(let i=0;i<toolkit.fet_devices.olimex.length;i++) {
        new_item    = document.createElement("menuitem");
        toolkit.device_list.appendChild(new_item);
        new_item.value = new_item.label = toolkit.fet_devices.olimex[i];
     }
    });
  },
};


toolkit.epv = {
  batch_count:0,
            
  start:function(){
    toolkit.hexfile = document.getElementById('hexfile').value;
    toolkit.device  = document.getElementById('device').value;
    toolkit.erase   = document.getElementById('erase').value;
    toolkit.console = document.getElementById('console');

    pmon=setInterval("console.value = console.value + '.';",500);
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
      })
    },

    // ---- SELECT TARGET ---- //  
    function(){
      mspdebughelper.callCommand('select_target', [toolkit.device], function(data){
        switch(data.result){
          // All done
          case 0:
            toolkit.epv.call_batch();
            break;

          // unhandled error
          default :
            throw('unhandled error');
        }
      })
    },
      
    // ---- OPEN NEW SESSION ---- //
    function(){
      mspdebughelper.callCommand('open_debug_session', [], function(data){
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
            toolkit.epv.call_batch();
            break;

          // unhandled error
          default :
            throw('unhandled error');
        }
      })
    },

    // ---- SELECT FIRMWARE ---- //
    function(){
      mspdebughelper.callCommand('select_firmware', [toolkit.hexfile], function(data){
        switch(data.result){
          // firmware file download error
          case 4:
            throw('firmware file download error');
            break;

          // All done
          case 0:
            toolkit.epv.call_batch();
            break;

          // unhandled error
          default:
            throw('unhandled error');
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

          // unhandled error
          default :
            throw('unhandled error');
         }              
      })
    },
      
    // ---- PROGRAM TARGET ---- //
    function(){
      mspdebughelper.callCommand('program', [], function(data){
        clearInterval(pmon);
        switch(data.result){
          // program error
          case 5:
            throw('program error');
            break;

          // All done
          case 0:
            toolkit.epv.call_batch();
            break;

          // unhandled error
          default :
            throw('unhandled error');  
        }
      })
    },
      
    // ---- VERIFY TARGET ---- //
    function(){
      mspdebughelper.callCommand('verify', [], function(data){
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
}

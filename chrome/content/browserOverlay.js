/*****************************************************************************
 * SETUP PRIVATE OBJECT
 *****************************************************************************/

if (typeof mspedebughelper == "undefined") var mspedebughelper = {};

mspdebughelper = {
/*****************************************************************************
 * GLOBAL PARAMS
 *****************************************************************************/


/*****************************************************************************
 * Extension initialization
 *****************************************************************************/
  init: function ()
  {
    // Publish javascript core object
    gBrowser.mspdebughelper = this;

    // Activate the comunication stack with the untrusted code
    document.addEventListener(
      "mspdebughelper",
      this.rpcListener,
      false,
      true
    ); 

    // gets preferences
    this._prefService =
      Components.classes["@mozilla.org/preferences-service;1"]
        .getService(Components.interfaces.nsIPrefBranch)
        .getBranch("extensions.mspdebughelper.programmer.");
        

    this._prefService.addObserver("",{ 
      observe:function(subject,topic,data) {
        if(topic == "nsPref:changed") mspdebughelper.upgradeSettingsFile();
      }
    },false);
    
            
//alert(this._prefService.getCharPref("extensions.mspdebughelper.programmer.driver"));
//alert(this._prefService.getCharPref("extensions.mspdebughelper.programmer.paths_mspdebug"));

    this._preferences = this._prefService.getChildList("",{});

    // Get the extension path
    Components.utils.import("resource://gre/modules/AddonManager.jsm");    

    AddonManager.getAddonByID("mspdebughelper@soundcafe.it",
      function(addon) {
        mspdebughelper.addonLocation = addon.getResourceURI("")
          .QueryInterface(Components.interfaces.nsIFileURL).file.path;
      }
    )

    // Setup locale file reference
    this._bundlePreferences = document
      .getElementById("mspdebughelper_bundlePreferences");
  },


/*****************************************************************************
 * Shows about window
 *****************************************************************************/
  showAbout: function()
  {
    window.openDialog("chrome://mspdebughelper/content/about.xul",
      "mspdebughelper-about-window", "chrome,modal,centerscreen,dialog");
  },


/*****************************************************************************
 * Shows console window
 *****************************************************************************/
  showConsole: function()
  {
    window.open("chrome://mspdebughelper/content/console/main.xul",
      "mspdebughelper-console-window", "chrome,centerscreen");
  },


/*****************************************************************************
 * Shows settings window
 *****************************************************************************/
  showPreferences: function() {
    if (null == this._preferencesWindow || this._preferencesWindow.closed) {
      let instantApply = 
        Application.prefs.get("browser.preferences.instantApply");

      let features = "chrome,titlebar,toolbar,centerscreen" +
                     (instantApply.value ? ",dialog=no" : ",modal");
   
      this._preferencesWindow =
        window.openDialog(
          "chrome://mspdebughelper/content/preferences/main.xul",
          "mspdebughelper-preferences-window", features);
    }
 
    this._preferencesWindow.focus();
  },


/*****************************************************************************
 * Shows toolkit window
 *****************************************************************************/
  showToolkit: function()
  {
    window.open("chrome://mspdebughelper/content/toolkit/main.xul",
      "mspdebughelper-toolkit-window", "chrome,centerscreen");
  },


/*****************************************************************************
 * Call programming functions 
 *****************************************************************************/
  callCommand: function(commandName, data, callback)
  {
    // some checks
    if (!this.get_workdir()) {
      alert(this._bundlePreferences.getString("not_valid_workdir"));
      return false;
    }

    if (!this.get_mspdebug_path()) {
      alert(this._bundlePreferences.getString("not_valid_mspdebug"));
      return false;
    }

    if (!this.check_libmsp430()) {
      alert(this._bundlePreferences.getString("not_valid_libmsp430"));
      return false;
    }

    // avoid concurency calls
    if(this.commandIsRunning == true) return false;
    this.commandIsRunning = true;

    // hooks main process
    let commandPath     = this.addonLocation + "/bin/program.sh"
    let commandInstance = this.get_file_instance(commandPath, true);

    if (!commandInstance) {
      alert(this._bundlePreferences.getString("not_valid_program"));
      return false;
    }
            
    let processInstance = Components.classes["@mozilla.org/process/util;1"]
      .createInstance(Components.interfaces.nsIProcess);

    processInstance.init(commandInstance);

    data.unshift(commandName);    

    // executes the main process unless stop the program flow
    processInstance.runAsync(data, data.length, { 
      observe:function(subject,topic,data) {
        if (topic == "process-finished") {
          mspdebughelper.commandIsRunning = false;
          let processInstance = subject
            .QueryInterface(Components.interfaces.nsIProcess);
          callback({result:processInstance.exitValue});

        } 
      }
    });
  },


/*****************************************************************************
 * Upgrade settings file in /bin
 *****************************************************************************/
  upgradeSettingsFile: function()
  {
    // some checks
    let workDir = this.get_workdir();

    if (!this.get_workdir()) {
      alert(this._bundlePreferences.getString("not_valid_workdir"));
      return false;
    }

    // hooks main process
    let commandPath     = this.addonLocation + "/bin/write_settings.sh";
    let commandInstance = this.get_file_instance(commandPath, true);

    if (!commandInstance) {
      alert(this._bundlePreferences.getString("not_valid_write_settings"));
      return false;
    }
 
    let processInstance = Components.classes["@mozilla.org/process/util;1"]
      .createInstance(Components.interfaces.nsIProcess);
      
    processInstance.init(commandInstance);

    for (let key in this._preferences) {
      let propertyName = this._preferences[key];
      let propertyValue = this._prefService.getComplexValue(propertyName
          ,Components.interfaces.nsIPrefLocalizedString).data;

      let data = [workDir,'set',propertyName,propertyValue];
      processInstance.run(true,data,data.length);

      if (processInstance.exitValue != 0) {
        Application.console.log("mspdebughelper : " + 
          this._bundlePreferences.getFormattedString("processInstanceExitValue"
          ,[commandPath, processInstance.exitValue].concat(data.join(', '))));
        return false;
      }
    }

    return true;
  },


/*****************************************************************************
 * Enables monitoring functions
 *****************************************************************************/
  setupMonitor: function()
  {
  },


/*****************************************************************************
 * Handle messages between the plugin code and the untrusted remote code
 *****************************************************************************/
  rpcListener: function(event)
  {
    var node = event.target;
    var odoc = node.ownerDocument;
    var data = node.getUserData("data");
    var comm = data.shift();

    // Call the function hub and builds a 'per-call' callback function
    return this.callCommand(comm, data, function(data){
      if (!node.getUserData("c")) return odoc.documentElement.removeChild(node);
      node.setUserData("data", data, null);
      var listener = odoc.createEvent("HTMLEvents");
      listener.initEvent(tokn, true, false);
      return node.dispatchEvent(listener);
    });
  },


/*****************************************************************************
 * Checks if the workdir has been defined and returs it's path
 *****************************************************************************/
  get_workdir: function()
  {
    let workdir = this._prefService
      .getComplexValue("paths_workdir"
        ,Components.interfaces.nsIPrefLocalizedString).data;

    if (workdir == null | workdir == '') return false;

    let file = this.get_file_instance(workdir, true, true);

    if (file)    

      return workdir;

    else

      return false
  },


/*****************************************************************************
 * Checks if the MSPDebug executable has been defined and returs it's path
 *****************************************************************************/
  get_mspdebug_path: function()
  {
    let mspdebug = this._prefService
      .getComplexValue("paths_mspdebug"
        ,Components.interfaces.nsIPrefLocalizedString).data;

    if (mspdebug == null | mspdebug == '') {
      Application.console.log("mspdebughelper : "
        + this._bundlePreferences.getFormattedString("not_path_mspdebug",[]));

      return false;
    }

    let file = this.get_file_instance(mspdebug, true);
     
    if (file) return mspdebug;
     
    Application.console.log("mspdebughelper : " + this._bundlePreferences
      .getFormattedString("not_valid_mspdebug",[mspdebug]));
      
    return false
  },

/*****************************************************************************
 * Checks for a valid libmsp430.so if tilib driver has been set
 *****************************************************************************/
  check_libmsp430: function()
  {
    let libmsp430 = this._prefService
      .getComplexValue("paths_libmsp430"
        ,Components.interfaces.nsIPrefLocalizedString).data;

    let driver = this._prefService
      .getComplexValue("driver"
        ,Components.interfaces.nsIPrefLocalizedString).data;

    if (driver != 'tilib') return true;

    if (libmsp430 == null | libmsp430 == '') {
      Application.console.log("mspdebughelper : "
        + this._bundlePreferences.getFormattedString("not_path_libmsp430",[]));

      return false;
    }

    if (this.get_file_instance(libmsp430)) return true;
    
    Application.console.log("mspdebughelper : " + this._bundlePreferences
      .getFormattedString("not_valid_libmsp430",[]));

    return false;
  },

/*****************************************************************************
 * Read one of the debug files
 *****************************************************************************/
  read: function(target, param = null)
  {
    let workDir = this.get_workdir();
    let path;
    
    if (!workDir) {
      alert(this._bundlePreferences.getString("not_valid_workdir"));           
      return false;
    }

    switch(target) {
      case 'anonymous' : path = "/tmp/mspdebughelper_anonymous.log"; break;
      case 'main' :      path = workDir + "/main.log";               break;      
      case 'gdb' :       path = workDir + "/gdb.log";                break;
      default :          path = workDir + target;                    break;
    }


    let file = this.get_file_instance(path);
    
    if (!file) return false;
        
    var data = "";
    var fstream = Components
                 .classes["@mozilla.org/network/file-input-stream;1"]
                 .createInstance(Components.interfaces.nsIFileInputStream);
    var cstream = Components
                 .classes["@mozilla.org/intl/converter-input-stream;1"]
                 .createInstance(Components.interfaces.nsIConverterInputStream);
                  
    fstream.init(file, -1, 0, 0);
    cstream.init(fstream, "UTF-8", 0, 0);
     
    let (str = {}) {
      let read = 0;
      do { 
        read  = cstream.readString(0xffffffff, str);
        data += str.value;
      } while (read != 0);
    }
 
    cstream.close();
     
    return data;
  },

/*****************************************************************************
 * File instance helper
 *****************************************************************************/
  get_file_instance: function(path,x=false,d=false)
  {
    var file = Components.classes["@mozilla.org/file/local;1"]
              .createInstance(Components.interfaces.nsILocalFile);
           
    file.initWithPath(path);

    if(!file.exists()) {
      Application.console.log("mspdebughelper : " + this._bundlePreferences
        .getFormattedString("not_exists_file",[path]));
        
      return false;     
    }

    if(!d & !file.isFile()) {
      Application.console.log("mspdebughelper : " + this._bundlePreferences
        .getFormattedString("not_a_file",[path]));
        
      return false;     
    }

    if(d & !file.isDirectory()) {
      Application.console.log("mspdebughelper : " + this._bundlePreferences
        .getFormattedString("not_a_directory",[path]));
        
      return false;     
    }
 
    if(!file.isReadable()) {
      Application.console.log("mspdebughelper : " + this._bundlePreferences
        .getFormattedString("not_readable_file",[path]));

      return false;      
    }
 
    if(!file.isExecutable() & x) {
      Application.console.log("mspdebughelper : " + this._bundlePreferences
        .getFormattedString("not_executable_file",[path]));      

      return false;
    }
     
    return file;    
  },

/*****************************************************************************
 * File picker helper
 *****************************************************************************/  
  f_picker: function(target)  
  {  
    const nsIFilePicker = Components.interfaces.nsIFilePicker;  
    const nsILocalFile  = Components.interfaces.nsILocalFile;  
    
    var fp = Components.classes["@mozilla.org/filepicker;1"]  
                       .createInstance(nsIFilePicker);  
    
    var title = target.getAttribute("title");  
    
    fp.appendFilters(nsIFilePicker.filterApps);  
    fp.init(window, title, nsIFilePicker.modeOpen);  
    
    if (fp.show() == nsIFilePicker.returnOK) {  
  	 target.value = fp.file.path;  
    }  
  }
}


/*****************************************************************************
 * Attach initialization code to onload event
 *****************************************************************************/
window.addEventListener(
  "load",
  function(){mspdebughelper.init();},
  false,
  true
);


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

  /**
   * Call programming functions 
   */
  callCommand: function(commandName, data, callback)
  {
    // some checks
    if (!this.getWorkdir()) {
      alert(this._bundlePreferences.getString("notValidWorkdir"));
      return false;
    }

    if (!this.getMSPDebugExecutable()) {
      alert(this._bundlePreferences.getString("notValidMSPDebug"));
      return false;
    }

    if (!this.checkLibmsp430()) {
      alert(this._bundlePreferences.getString("notSetLibmsp430"));
      return false;
    }

    // avoid concurency calls
    if(this.commandIsRunning == true) return false;
    this.commandIsRunning = true;

    // hooks main process
    let commandInstance = Components.classes["@mozilla.org/file/local;1"]
      .createInstance(Components.interfaces.nsILocalFile);
    let processInstance = Components.classes["@mozilla.org/process/util;1"]
      .createInstance(Components.interfaces.nsIProcess);

    commandInstance.initWithPath(this.addonLocation + "/bin/program.sh");
    processInstance.init(commandInstance);

    if (!commandInstance.isExecutable()) {
      Application.console.log("mspdebughelper : " + this._bundlePreferences
        .getFormattedString("notExecutableFile"
          ,[this.addonLocation + "/bin/program.sh"]));
      return false;
    }

    // futher actions made depending by the command
    switch(commandName) {
      case 'open_debug_session':
        if (!this.upgradeSettingsFile()) return false;
        break;
    }

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

  upgradeSettingsFile: function()
  {
    // some checks
    let workDir = this.getWorkdir();

    if (!this.getWorkdir()) {
      alert(this._bundlePreferences.getString("notValidWorkdir"));
      return false;
    }

    // hooks main process
    let commandPath = this.addonLocation + "/bin/write_settings.sh";
    let commandInstance = Components.classes["@mozilla.org/file/local;1"]
      .createInstance(Components.interfaces.nsILocalFile);
    let processInstance = Components.classes["@mozilla.org/process/util;1"]
      .createInstance(Components.interfaces.nsIProcess);

    commandInstance.initWithPath(commandPath);
    processInstance.init(commandInstance);

    if (!commandInstance.isExecutable()) {
      Application.console.log("mspdebughelper : " + this._bundlePreferences
        .getFormattedString("notExecutableFile",[commandPath]));
      return false;
    }

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

  /**
   * Enables monitoring functions
   */
  setupMonitor: function()
  {
  },

  /**
   * Handle messages between the plugin code and the untrusted remote code
   */
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

  /**
   * Checks if the workdir has been defined and returs it's path
   */
  getWorkdir: function()
  {
    let workdir = this._prefService
      .getComplexValue("paths_workdir"
        ,Components.interfaces.nsIPrefLocalizedString).data;

    if (workdir == null | workdir == '') return false;

    let commandInstance = Components.classes["@mozilla.org/file/local;1"]
          .createInstance(Components.interfaces.nsILocalFile);

    commandInstance.initWithPath(workdir);

    if (commandInstance.isDirectory() 
        & commandInstance.isReadable()
        & commandInstance.isWritable())
      return workdir;
    else
      return false
  },

  /**
   * Checks if the MSPDebug executable has been defined and returs it's path
   */
  getMSPDebugExecutable: function()
  {
    let mspdebug = this._prefService
      .getComplexValue("paths_mspdebug"
        ,Components.interfaces.nsIPrefLocalizedString).data;

    if (mspdebug == null | mspdebug == '') return false;

    let commandInstance = Components.classes["@mozilla.org/file/local;1"]
          .createInstance(Components.interfaces.nsILocalFile);

    commandInstance.initWithPath(mspdebug);

    if (commandInstance.isFile() 
        & commandInstance.isReadable()
        & commandInstance.isExecutable())
      return mspdebug;
    else
      Application.console.log("mspdebughelper : " + this._bundlePreferences
        .getFormattedString("notExecutableFile",[mspdebug]));
      return false
  },

  /**
   * Checks if the path of libmsp430 if tilib driver as been set
   */
  checkLibmsp430: function()
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
        + this._bundlePreferences.getFormattedString("notSetLibmsp430",[]));
      return false;
    }

    let commandInstance = Components.classes["@mozilla.org/file/local;1"]
          .createInstance(Components.interfaces.nsILocalFile);

    commandInstance.initWithPath(libmsp430);

    if (commandInstance.isFile() & commandInstance.isReadable())

      return libmsp430;
      
    else

      Application.console.log("mspdebughelper : " + this._bundlePreferences
        .getFormattedString("notValidLibmsp430",[libmsp430]));

      return false

  },

  read: function(target, param = null)
  {
    let workDir = this.getWorkdir();

    if (!workDir) {
      alert(gBrowser
            .mspdebughelper
            ._bundlePreferences
            .getString("notValidWorkdir"));
            
      return false;
    }

    switch(target) {
      case 'anonymous' : path = "/tmp/mspdebughelper_anonymous.log"; break;
      case 'main' :      path = workDir + "/main.log";               break;      
      case 'gdb' :       path = workDir + "/gdb.log";                break;
    }

    var file = Components.classes["@mozilla.org/file/local;1"]
              .createInstance(Components.interfaces.nsILocalFile);
           
    file.initWithPath(path);
    
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

  file_picker: function(target)  
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


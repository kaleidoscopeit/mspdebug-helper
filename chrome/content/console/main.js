var console = {
  init: function()
  {
    window.gBrowser = window.opener.getBrowser();
  },

  refresh_anonymous: function()
  {
    let anonymous_data = this.read("/tmp/mspdebughelper_anonymous.log");
    let anonymousLog = document.getElementById('anonymousLog');
    anonymousLog.value = anonymous_data;
    let pos = anonymousLog.value.length;
    anonymousLog.selectionStart = pos;
    anonymousLog.selectionEnd = pos;

  },

  refresh_mainlog: function()
  {
    let workDir = gBrowser.mspdebughelper.getWorkdir();

    if (!workDir) {
      alert(gBrowser
            .mspdebughelper
            ._bundlePreferences
            .getString("notValidWorkdir"));
            
      return false;
    }

    let mainlog_data = this.read(workDir + "/main.log");
    let mainLog = document.getElementById('mainLog');
    mainLog.value = mainlog_data;
    let pos = mainLog.value.length;
    mainLog.selectionStart = pos;
    mainLog.selectionEnd = pos;
  },
  
/*****************************************************************************
 * read a file                                                               *
 *****************************************************************************/
  read: function(path)
  {
    var file = Components.classes["@mozilla.org/file/local;1"].
           createInstance(Components.interfaces.nsILocalFile);
           
    file.initWithPath(path);
    
    var data = "";
    var fstream = Components.classes["@mozilla.org/network/file-input-stream;1"].
                  createInstance(Components.interfaces.nsIFileInputStream);
    var cstream = Components.classes["@mozilla.org/intl/converter-input-stream;1"].
                  createInstance(Components.interfaces.nsIConverterInputStream);
                  
    fstream.init(file, -1, 0, 0);
    cstream.init(fstream, "UTF-8", 0, 0);
     
    let (str = {}) {
      let read = 0;
      do { 
        read = cstream.readString(0xffffffff, str);
        data += str.value;
      } while (read != 0);
    }
    cstream.close(); // this closes fstream
     
    return data;
  },
  
  test: function()
  {
    gBrowser.mspdebughelper
      .callCommand('open_debug_session', Array(), function(){
        alert('finished');
      });


  }
  
}
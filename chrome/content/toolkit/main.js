function showPanel(elem)
{
  document.getElementById("toolkitTabbox").selectedPanel = 
    document.getElementById(elem);
};

var rawCommands = {
  init: function()
  {
    window.gBrowser = window.opener.getBrowser();
  },

  open_debug_session: function()
  {
    gBrowser.mspdebughelper
      .callCommand('open_debug_session', Array(), function(){
        alert('finished');
      });


  }
}

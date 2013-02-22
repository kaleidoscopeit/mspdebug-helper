var console = {
  init: function()
  {
    window.gBrowser = window.opener.getBrowser();
    window.mspdebughelper =  gBrowser.mspdebughelper;
    setInterval(function(){with(console){
      fill_console('anonymous');
      fill_console('main');
      fill_console('gdb');
    }},1000);
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

  test: function()
  {
    gBrowser.mspdebughelper
      .callCommand('open_debug_session', Array(), function(){
        alert('finished');
      });


  }
  
}
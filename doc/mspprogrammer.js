// Client side handler function

mspdebughelper={
/*	open_debug_session:function(cbk){this.send(Array('open_debug_session'),cbk);},
	close_debug_session:function(cbk){this.send(Array('close_debug_session'),cbk);},
	erase:function(p,cbk){this.send(Array('erase',p),cbk);},
	select_firmware:function(p,cbk){this.send(Array('select_firmware',p),cbk);},
	select_target:function(t,cbk){this.send(Array('select_target',t),cbk);},
	program:function(cbk){this.send(Array('program'),cbk);},
	verify:function(cbk){this.send(Array('verify'),cbk);},
	program_monitor:function(cbk){this.send(Array('program_monitor'),cbk);},
	verify_monitor:function(cbk){this.send(Array('verify_monitor'),cbk);},
	write_string:function(data,cbk){this.send(Array('write_string').concat(data),cbk);},*/
	
	callCommand:function(command, argv, callback){
		var d=document,rq=d.createElement("MSPDdebugHelperElm"),s=d.createEvent("Events");
		rq.setAttribute("command",command);
    for(var argn in argv) rq.setAttribute(argn,argv[argn]);

		if(callback){
			rq.setAttribute("callback",callback);
			d.addEventListener(command, function(e){
				var target=e.target;
				for(var i=0;i<target.attributes.length;i++)
				  rs[target.attributes[i].name]=target.attributes[i].value;

				d.documentElement.removeChild(n);
				d.removeEventListener(command, arguments.callee, false);
				callback(rs);
			},false);
 		}
		d.documentElement.appendChild(rq);
		s.initEvent("MSPDdebugHelperEvt",true,false);
		rq.dispatchEvent(s);
 	}, 	
};
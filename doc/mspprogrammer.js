// Client side handler function

mspprogrammer={
	open_debug_session:function(cbk){this.send(Array('open_debug_session'),cbk);},
	close_debug_session:function(cbk){this.send(Array('close_debug_session'),cbk);},
	erase:function(p,cbk){this.send(Array('erase',p),cbk);},
	select_firmware:function(p,cbk){this.send(Array('select_firmware',p),cbk);},
	select_target:function(t,cbk){this.send(Array('select_target',t),cbk);},
	program:function(cbk){this.send(Array('program'),cbk);},
	verify:function(cbk){this.send(Array('verify'),cbk);},
	program_monitor:function(cbk){this.send(Array('program_monitor'),cbk);},
	verify_monitor:function(cbk){this.send(Array('verify_monitor'),cbk);},
	write_string:function(data,cbk){this.send(Array('write_string').concat(data),cbk);},
	
	send:function(data,cbk){
		var d=document,rq=d.createTextNode(""),s=d.createEvent("HTMLEvents");
		rq.setUserData("data",data,null);
		if(cbk){
			rq.setUserData("c",cbk,null);
			d.addEventListener(data[0],function(e){
				var n=e.target,rs=n.getUserData("data");
				d.documentElement.removeChild(n);
				d.removeEventListener(data[0],arguments.callee,false);
				cbk(rs);
			},false);
 		}
		d.documentElement.appendChild(rq);
		s.initEvent("mspdebug",true,false);
		rq.dispatchEvent(s);
 	}, 	
};

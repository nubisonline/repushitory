#!/usr/bin/ruby
require 'socket'
require 'json'
webserver = TCPServer.new('127.0.0.1', 3210)
while (session = webserver.accept)
	contentlength = 0
	while (buff = session.gets)
		if(buff == "\n" || buff == "\r\n")
			break
		else
			if(buff[0,14] == "Content-Length")
				contentlength = buff[16..-1].to_i
			end
		end
	end
	content = session.read(contentlength)
	session.print "HTTP/1.1 200/OK\nContent-type:text/html\n\n"
	begin
		push = JSON.parse(content)
		ref = push["ref"]
		name = push["repository"]["name"]
	end
	session.close
end

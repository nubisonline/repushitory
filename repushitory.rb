#!/usr/bin/env ruby
require 'socket'
require 'net/ftp'
require 'fileutils'
require 'rubygems'
require 'json'
require 'git'


#Set up folders and configuration
config = nil
servers = nil

progdir = File.join(Dir.home, ".repushitory")

if(File.exists?(progdir))
	Dir.chdir(progdir)
	begin
		confdata = File.read("config.json")
		config = JSON.parse(confdata)
	rescue Exception => e
	end
	begin
		serverdata = File.read("servers.json")
		servers = JSON.parse(serverdata)
	rescue Exception => e
	end
else
	Dir.mkdir(progdir, 0700)
	Dir.chdir(progdir)
end

Dir.mkdir("repos", 0700) unless File.exists?("repos")

if(config.nil? || servers.nil?)
	puts "config.json or servers.json doesn't exists or isn't in the right (JSON) format. The files should be in " + progdir
	Process.exit(1)
end

#Set up listening server
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
		#Parse payload
		push = JSON.parse(content)
		ref = push["ref"]
		repo = push["repository"]["name"]
		owner = push["repository"]["owner"]["name"]
		branch = ref.split("/").last

		Dir.chdir("repos")

		#Check config files for match
		config["repositories"].each do |repository|
			if(repository["owner"] == owner && repository["repo"] == repo)
				#Repo is in the config file, take action
				connection = "git@github.com:" + owner + "/" + repo + ".git"
				git_repository = Git.clone(connection, repo)

				Dir.chdir(repo)

				repository["actions"].each do |action|
					if(action["branch"] == branch)
						git_repository.checkout(git_repository.branch(branch))
						
						server = nil
						servers["servers"].each do |server|
							destination = action["destination"]
							if(server["name"] == destination["server"])
								#We should abstract from this
								ftp = Net::FTP.new
								ftp.passive = true
								ftp.connect(server["host"])
								ftp.login(server["user"],server["pass"])
								ftp.chdir(server["path"])
								ftp.chdir(action["folder"])
								
								#Recursively upload the repo

								puts ftp.last_response
								ftp.quit
							end
						end
					end
				end

				Dir.chdir("..")
				FileUtils.rm_rf(repo)
			end
		end

		Dir.chdir("..")
	end
	session.close
end

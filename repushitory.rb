#!/usr/bin/env ruby
require 'socket'
require 'net/ftp'
require 'cgi'
require 'fileutils'
require 'logger'
require 'rubygems'
require 'json'
require 'git'
require 'listen'

load 'binary.rb'
load 'upload.rb'
load 'watchconf.rb'
load 'config.class.rb'

#Set up folders and configuration
configs = Configs.new
configs.config = nil
configs.servers = nil
logger = nil

progdir = File.join(Dir.home, ".repushitory")
repodir = File.join(progdir, "repos")

if(File.exists?(progdir))
	Dir.chdir(progdir)
	begin
		confdata = File.read("config.json")
		configs.config = JSON.parse(confdata)
	rescue Exception => e
	end
	begin
		serverdata = File.read("servers.json")
		configs.servers = JSON.parse(serverdata)
	rescue Exception => e
	end
else
	Dir.mkdir(progdir, 0700)
	Dir.chdir(progdir)
end

Dir.mkdir("repos", 0700) unless File.exists?("repos")

if(configs.config.nil? || configs.servers.nil?)
	puts "config.json or servers.json doesn't exists or isn't in the right (JSON) format. The files should be in " + progdir
	Process.exit(1)
end


#Set up logging
if(configs.config["logfile"] != "")
	logger = Logger.new(configs.config["logfile"])
else
	logger = Logger.new(STDOUT)
end

logger.info("Repushitory starting")

filewatcht = Thread.new{startfilewatch(progdir, logger, configs)}

#Set up listening server
webserver = TCPServer.new('0.0.0.0', 3210)
logger.info("Webserver started");
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
		payload = CGI::unescape(content[8..-1])
		push = JSON.parse(payload)
		ref = push["ref"]
		repo = push["repository"]["name"]
		owner = push["repository"]["owner"]["name"]
		branch = ref.split("/").last

		Dir.chdir(repodir)

		logger.info("Got request for " + owner + "/" + repo + "/" + branch)

		#Check config files for match
		configs.config["repositories"].each do |repository|
			if(repository["owner"] == owner && repository["repo"] == repo)
				#Repo is in the config file, take action

				if(not File.exists?(owner))
					Dir.mkdir(owner, 0700)
				end
				Dir.chdir(owner)
				
				connection = "git@github.com:" + owner + "/" + repo + ".git"
				
				if(not File.exists?(repo + "/.git"))
					git_repository = Git.clone(connection, repo)
				else
					git_repository = Git.open(repo)
				end

				Dir.chdir(repo)

				repository["actions"].each do |action|
					if(action["branch"] == branch)
						git_repository.checkout(git_repository.branch(branch))
						git_repository.pull('origin', 'origin/' + branch, 'pull ' + branch)
						
						commits = push["commits"]
						to_upload = []
						to_remove = []
						commits.each do |commit|
							commit["added"].each do |file|
								to_remove.delete(file) if to_remove.include?(file)
								to_upload.push(file) unless to_upload.include?(file)
							end
							commit["modified"].each do |file|
								to_upload.push(file) unless to_upload.include?(file)
							end
							commit["removed"].each do |file|
								to_upload.delete(file) if to_upload.include?(file)
								to_remove.push(file) unless to_remove.include?(file)
							end
						end
						
						server = nil
						configs.servers["servers"].each do |server|
							destination = action["destination"]
							if(server["name"] == destination["server"])
								#We should abstract from this
								ftp = Net::FTP.new
								ftp.passive = true
								ftp.connect(server["host"])
								ftp.login(server["user"],server["pass"])
								ftp.chdir(server["path"])
								ftp.chdir(destination["path"])
								Dir.chdir(action["folder"])
								
								variables = []
								if(action.has_key?("variables"))
									variables = action["variables"]
								end
								
								ignore = []
								if(action.has_key?("ignore"))
									ignore = action["ignore"]
								end
								
								compiler = ""
								if(configs.config.has_key?("lessc"))
									compiler = configs.config["lessc"]
								end
								
								less = repository.has_key?("less")
								
								upload(to_upload, to_remove, ftp, variables, ignore, less, compiler)

								ftp.quit
							end
						end
					end
				end

				Dir.chdir(repodir)
			end
		end

		Dir.chdir("..")
		
		logger.info("Done with request for " + owner + "/" + repo + "/" + branch)
	end
	session.close
end

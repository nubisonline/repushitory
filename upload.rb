def upload(to_upload, to_remove, ftp, variables, ignore, less, compiler)
	to_upload.each do |file|
		folder = File.dirname(file)
		folders = []
		if(folder != ".")
			folders = folder.split("/")
		end
		file = File.basename(file)
		
		folders.each do |dir|
			begin
				ftp.mkdir(dir)
			rescue
			end
			ftp.chdir(dir)
			Dir.chdir(dir)
		end
		
		if(File.binary?(file))
			ftp.putbinaryfile(file)
		else
			if(variables.count > 0)
				txtfile = File.open(file)
				filetext = txtfile.read
				variables.each do |var|
					filetext = filetext.gsub(var["name"], var["value"])
				end
				txtfile.close
				txtfile = File.new(file, "w")
				txtfile.print(filetext)
				txtfile.close
			end
			
			if(less and File.extname(file).eql? ".less")
				cssname = File.basename(file, ".less") + ".css"
				`#{compiler} #{file} > #{cssname}`
				file = cssname
			end
			
			ftp.puttextfile(file)
		end
		
		folders.size.times do
			ftp.chdir("..")
			Dir.chdir("..")
		end
		
	end

	to_remove.each do |file|
		folder = File.dirname(file)
		folders = []
		if(folder != ".")
			folders = folder.split("/")
		end
		file = File.basename(file)
		
		folders.each do |dir|
			begin
				ftp.mkdir(dir)
			rescue
			end
			ftp.chdir(dir)
			Dir.chdir(dir)
		end
		
		begin
			ftp.delete(file)
		rescue
		end
		
		folders.size.times do
			ftp.chdir("..")
			Dir.chdir("..")
		end
		
	end
end

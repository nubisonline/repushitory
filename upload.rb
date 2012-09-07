def upload(ftp, variables, ignore, less, compiler)
	Dir.foreach(".") do |node|
		next if node == '.' or node == '..' or node == '.git' or ignore.include?(node)

		if(File.directory?(node))
			begin
				ftp.mkdir(node)
			rescue
			end
			ftp.chdir(node)
			Dir.chdir(node)

			upload(ftp, variables)

			ftp.chdir("..")
			Dir.chdir("..")
		else
			file = File.open(node)
			filecontents = file.read
			if(File.binary?(file))
				ftp.putbinaryfile(node)
				file.close
			else
				if(variables.count > 0)
					textfile = filecontents
					variables.each do |var|
						textfile = textfile.gsub(var["name"], var["value"])
					end
					file.close
					file = File.new(node, "w")
					file.print(textfile)
				end
				file.close
				
				if(less and File.extname(file).eql? ".less")
					cssname = File.basename(node, ".less") + ".css"
					system(compiler + " " + node + " " + cssname)
					node = cssname
				end
				
				ftp.puttextfile(node)
			end
		end
	end
end

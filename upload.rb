# Add binary test to File. Method by of Alex Gutteridge.
class File
	def is_binary?
		ascii = 0
		total = 0
		self.rewind
		self.read(1024).each_byte{|c| total += 1; ascii +=1 if c >= 128 or c == 0}
		ascii.to_f / total.to_f > 0.33 ? true : false
	end
end

def upload(ftp, variables)
	Dir.foreach(".") do |node|
		next if node == '.' or node == '..' or node == '.git'

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
			if(file.is_binary?)
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
				ftp.puttextfile(node)
			end
		end
	end
end

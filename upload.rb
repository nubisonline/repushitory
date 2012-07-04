def upload(ftp)
	Dir.foreach(".") do |node|
		next if node == '.' or node == '..' or node == '.git'
		
		if(File.directory?(node))
			begin
				ftp.mkdir(node)
			rescue
			end
			ftp.chdir(node)
			Dir.chdir(node)

			upload(ftp)

			ftp.chdir("..")
			Dir.chdir("..")
		else
			ftp.putbinaryfile(node)
		end
	end
end

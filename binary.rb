class File
	def self.binary?(filename)
		[".png", ".jpg", ".gif"].include?extname(filename)
	end
end
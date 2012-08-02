def startfilewatch(progdir, logger, configs)
	Listen.to(progdir, :relative_paths => true) do |modified, added, removed|
		if(modified.include?("config.json"))
			logger.info("Config file updated. New contents is:")
			begin
				confdata = File.read(File.join(progdir, "config.json"))
				configs.config = JSON.parse(confdata)
			rescue Exception => e
				logger.error(e.inspect)
			end
			logger.info(configs.config)
		end
		if(modified.include?("servers.json"))
			logger.info("Config file updated. New contents is:")
			begin
				serverdata = File.read(File.join(progdir, "servers.json"))
				configs.servers = JSON.parse(serverdata)
			rescue Exception => e
				logger.error(e.inspect)
			end
			logger.info(configs.servers)

		end
	end
end

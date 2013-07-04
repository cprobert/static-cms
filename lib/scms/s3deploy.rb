module S3Deploy
	VERSION = '1.0.0'
    require "scms/scms_utils.rb"

	def S3Deploy.sync(pub, config)
        @pub = pub
        ENV["S3CONF"] = config
        ENV["AWS_CALLING_FORMAT"] = "SUBDOMAIN"
        ENV["S3SYNC_MIME_TYPES_FILE"] = File.join(Folders[:root], "assets", "mime.types")

        yamlpath=File.join(config, "s3config.yml")
        $settings = YAML.load_file(yamlpath)
        
        ScmsUtils.log( "Syncing with Amazon S3: **#{$settings['bucket']}**" )
		
		removeold = "--delete"
		if $settings['clean'] != nil
			unless $settings['clean']
				removeold = ""
			end
		end
		
        cmd = "s3sync"
        cache = "--cache-control='max-age=31449600'"
        params = "--exclude='.svn' --progress --make-dirs --recursive --public-read #{removeold} #{cache} \"#{@pub}/\" #{$settings['bucket']}:/"
		if $settings['cache'] != nil
			$settings['cache'].each do |folder| 
				ScmsUtils.log( "Syncing **#{folder}** caching: 1 year" )
				ScmsUtils.run(cmd, params)
			end
		end

		cache = ""
		ScmsUtils.log( "Syncing **root** no caching" )
		ScmsUtils.run(cmd, params)
        ScmsUtils.successLog("**Deployed :)**")
        
        if $settings['uri'] != nil
			ScmsUtils.log("[_#{$settings['uri']}_](#{$settings['uri']})")
		end
	end	

    def S3Deploy.backup(privatedir, config)
        ENV["S3CONF"] = config
        ENV["AWS_CALLING_FORMAT"] = "SUBDOMAIN"
        ENV["S3SYNC_MIME_TYPES_FILE"] = File.join(Folders[:root], "assets", "mime.types")

        yamlpath=File.join(config, "s3config.yml")
        $settings = YAML.load_file(yamlpath)
        
        ScmsUtils.log( "Backing up to Amazon S3: **#{$settings['bucket']}**" )
        cmd = "s3sync"
        removeold = "--delete"
        if $settings['clean'] != nil
            unless $settings['clean']
                removeold = ""
            end
        end
        params = "--exclude='.svn' --progress --make-dirs --recursive #{removeold} \"#{privatedir}/\" #{$settings['bucket']}:/private"
        ScmsUtils.run(cmd, params)
        ScmsUtils.successLog("**Done :)**")
    end 
end
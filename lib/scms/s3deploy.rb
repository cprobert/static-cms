module S3Deploy
	VERSION = '1.0.0'
    require "scms/scms_utils.rb"

	def S3Deploy.sync(pub, config)
        @pub = pub
        ENV["S3CONF"] = config
        ENV["AWS_CALLING_FORMAT"] = "SUBDOMAIN"
        ENV["SSL_CERT_DIR"] = File.join($website, "s3certs")
        ENV["S3SYNC_MIME_TYPES_FILE"] = File.join(Folders[:root], "assets", "mime.types")

        puts "S3SYNC_MIME_TYPES_FILE: #{ENV["S3SYNC_MIME_TYPES_FILE"]}"
        puts "AWS_CALLING_FORMAT: #{ENV["AWS_CALLING_FORMAT"]}"
        puts "SSL_CERT_DIR: #{ENV["SSL_CERT_DIR"]}"
        puts "S3CONF: #{ENV["S3CONF"]}"

        #ScmsUtils.log( "Getting s3sync settings: \n#{config}\n\n")
        $settings = YAML.load_file(config)
        
        ScmsUtils.log( "Syncing with Amazon S3: **#{$settings['bucket']}**" )
		
		removeold = "--delete"
		if $settings['clean'] != nil
			unless $settings['clean']
				removeold = ""
			end
		end
		
        cmd = "s3sync"
		if $settings['cache'] != nil
			$settings['cache'].each do |folder| 
				script_params = "--exclude='.svn' --progress --make-dirs --recursive --public-read #{removeold} --cache-control='max-age=31449600' \"#{@pub}/#{folder}/\" #{$settings['bucket']}:#{folder}/"
				ScmsUtils.log( "Syncing **#{folder}** caching: 1 year" )
				ScmsUtils.run(cmd, script_params)
			end
		end

		nocache_params = "--progress --make-dirs --recursive --public-read #{removeold} \"#{@pub}/\" #{$settings['bucket']}:/"
		ScmsUtils.log( "Syncing **root** no caching" )
		ScmsUtils.run(cmd, nocache_params)
        
        ScmsUtils.successLog("**Deployed :)**")
        
        if $settings['uri'] != nil
			ScmsUtils.log("[_#{$settings['uri']}_](#{$settings['uri']})")
		end
	end	
end
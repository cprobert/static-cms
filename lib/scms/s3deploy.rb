module S3Deploy
    VERSION = '1.0.0'
    require "scms/scms-utils.rb"

    def S3Deploy.sync(pub, config)
        ScmsUtils.log( "Syncing with Amazon S3: #{$settings['bucket']}" )
        @pub = pub
        ENV["S3CONF"] = config
        ENV["AWS_CALLING_FORMAT"] = "SUBDOMAIN"
        ENV["S3SYNC_MIME_TYPES_FILE"] = File.join(Folders[:root], "assets", "mime.types")   

        yamlpath=File.join(config, "_s3config.yml")
        $settings = YAML.load_file(yamlpath)
        
        removeold = "--delete"
        if $settings['clean'] != nil
            unless $settings['clean']
                removeold = ""
            end
        end

        exclude = "(\\.svn$)|(^_)"
        if $settings['ignore'] != nil
            exclude = "#{exclude}|(#{$settings["ignore"]})"
        end
        
        cmd = "s3sync"
        params = "#{removeold} --exclude=\"#{exclude}\" --progress --make-dirs --recursive"

        #First deploy private directories
        Dir.glob("#{@pub}/_*/").each do |f|
            privatedir = File.basename(f)
            ScmsUtils.log( "Backing up #{privatedir} (private)" )
            privateparams = "#{params} \"#{@pub}/#{privatedir}/\" #{$settings['bucket']}:#{privatedir}/"
            ScmsUtils.run(cmd, privateparams)
        end
        
        #Them deploy publid dir with caching
        if $settings['cache'] != nil
            $settings['cache'].each do |folder| 
                ScmsUtils.log( "Syncing #{folder}(public: caching: 1 year)" )
                cacheparams = "#{params}  --public-read --cache-control='max-age=31449600' \"#{@pub}/#{folder}/\" #{$settings['bucket']}:#{folder}/"
                ScmsUtils.run(cmd, cacheparams)
            end
        end

        ScmsUtils.log( "Syncing root (public)" )
        roorparams = "#{params}  --public-read \"#{@pub}/\" #{$settings['bucket']}:/"
        #Finnaly deploy all remaining files (except excludes)
        ScmsUtils.run(cmd, roorparams)
        ScmsUtils.successLog("Deployed :)")
        
        if $settings['uri'] != nil
            ScmsUtils.log($settings['uri'])
        end
    end 
end
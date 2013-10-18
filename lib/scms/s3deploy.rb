module S3Deploy
    VERSION = '1.0.0'
    require "scms/scms-utils.rb"

    def S3Deploy.sync(pub, config, mimetypefile)
        #yamlpath=File.join(config, "_config.yml")
        #scmsSettings = ScmsUtils.readyaml(yamlpath)

        ENV["S3CONF"] = config
        ENV["AWS_CALLING_FORMAT"] = "SUBDOMAIN"
        ENV["S3SYNC_MIME_TYPES_FILE"] = mimetypefile
        #puts "S3SYNC_MIME_TYPES_FILE: #{ENV["S3SYNC_MIME_TYPES_FILE"] }"

        s3yamlpath=File.join(config, "_s3config.yml")
        settings = YAML.load_file(s3yamlpath)
        throw "No bucket defined in _s3config.yml settings file" if settings['bucket'] == nil
        ScmsUtils.boldlog( "Syncing with Amazon S3: #{settings['bucket']}" )

        exclude = "(\\.svn$)|(^_)"
        if settings['ignore'] != nil
            exclude = "#{exclude}|(#{settings["ignore"]})"
        end
        
        cmd = "s3sync"
        params = "--exclude=\"#{exclude}\" --progress --make-dirs --recursive"

        #First deploy private directories
        Dir.glob("#{pub}/_*/").each do |f|
            privatedir = File.basename(f)
            ScmsUtils.log( "Backing up: #{privatedir} (private)" )
            privateparams = "#{params} \"#{pub}/#{privatedir}/\" #{settings['bucket']}:#{privatedir}/"
            ScmsUtils.run(cmd, privateparams)
        end
        
        #Them deploy publid dir with caching
        if settings['cache'] != nil
            settings['cache'].each do |folder| 
                ScmsUtils.log("Publishing: #{folder}(public: caching: 1 year)")
                cacheparams = "#{params}  --public-read --cache-control='max-age=31449600' \"#{pub}/#{folder}/\" #{settings['bucket']}:#{folder}/"
                ScmsUtils.run(cmd, cacheparams)
            end
        end

        ScmsUtils.log("Publishing root (public)")
        removeold = ""
        removeold = "--delete"  if settings['clean'].to_s == "true"
        roorparams = "#{removeold} #{params} --public-read \"#{pub}/\" #{settings['bucket']}:/"
        #Finnaly deploy all remaining files (except excludes)
        ScmsUtils.run(cmd, roorparams)
        ScmsUtils.successLog("Deployed :)")
        
        if settings['uri'] != nil
            ScmsUtils.log(settings['uri'])
        end
    end 
end
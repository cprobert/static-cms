module ScmsWatcher
	require 'fileutils'
	require 'filewatcher'
	require 'pathname'
	require 'listen'

    def ScmsWatcher.watch(settings, options, configdir)
	    watcher = Thread.new {
	    	configfile = File.join(configdir, "_config.yml")
			FileWatcher.new([configfile]).watch do |filename|
				puts ""
				puts "***********************************"
				puts " Config Modification (_config.yml) "
				puts "***********************************"
				puts ""

				settings = Scms.getsettings(configdir)
				Scms.bundle(settings, Folders[:website])
				Scms.build(Folders[:website], settings, options[:mode])
			end
	    }

	    psst = []
	    psst.push("_views") if File.directory? "_views" # .html .htm .md .xml .erb, etc
	    psst.push("_layouts") if File.directory? "_layouts" # .html .htm .erb
	    psst.push("_templates") if File.directory? "_templates" # .html .htm .erb
	    psst.push("_resources") if File.directory? "_resources" # .yml
	    psst.push("_source") if File.directory? "_source" # .scss .css .js
	    
	    puts "Listening to #{psst}"
	    listener = Listen.to(psst, force_polling: true) do |modified, added, removed|
			# puts "modified: #{modified}" if modified.length > 0
			# puts "added: #{added}" if added.length > 0
			# puts "removed: #{removed}" if removed.length > 0

			if modified.length > 0
				sassfile = false
				bundlefile = false
				buildfile = true

				modified.each{|filename|
					modifiedfile = Pathname.new(filename).relative_path_from(Pathname.new(Folders[:website])).to_s
					ext = File.extname(modifiedfile)  

					puts ""
					puts "***********************************************"
					puts "  Modified: #{modifiedfile}"
					puts "***********************************************"
					puts ""

					if modifiedfile.start_with?('_source/')
						bundlefile = true
						buildfile = false
					end

					if ext == ".scss"
						sassfile = true
						bundlefile = false
						buildfile = false
						break
					end
				}

				Scms.sassall(Folders[:website]) if sassfile
				Scms.bundle(settings, Folders[:website]) if bundlefile
				Scms.build(Folders[:website], settings, options[:mode]) if buildfile
			end
	    end
	    listener.start # not blocking
	    listener.ignore! /\.png/
	    listener.ignore! /\.gif/
	    listener.ignore! /\.jpg/
    end
end

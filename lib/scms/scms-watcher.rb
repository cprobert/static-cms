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

				settings = Scms.getSettings(configdir)
				Scms.bundle(settings, Folders[:website])
				Scms.build(Folders[:website], settings, options[:mode], options[:watch])
			end
	    }

	    #  [todo] Create this by getting all directories that start with _
	    psst = []
	    psst.push("_pages") if File.directory? "_pages" # .html .htm .md .xml .erb, etc
	    psst.push("_views") if File.directory? "_views" # .html .htm .md .xml .erb, etc
	    psst.push("_layouts") if File.directory? "_layouts" # .html .htm .erb
	    psst.push("_templates") if File.directory? "_templates" # .html .htm .erb
	    psst.push("_resources") if File.directory? "_resources" # .yml
	    psst.push("_source") if File.directory? "_source" # .scss .css .js
	    
	    puts "Listening to #{psst}"
	    listener = Listen.to(psst, force_polling: true) do |modified, added, removed|

			sassfile = false
			bundlefile = false
			buildfile = false

			if removed.length > 0
				removed.each{|filename|
					removedfile = Pathname.new(filename).relative_path_from(Pathname.new(Folders[:website])).to_s
					#ext = File.extname(removedfile)  

					puts ""
					puts "***********************************************"
					puts "  Deleted: #{removedfile}"
					puts "***********************************************"
					puts ""

					if removedfile.start_with?('_pages/')
						buildfile = true
					end
				}
			end

			if added.length > 0
				added.each{|filename|
					addedfile = Pathname.new(filename).relative_path_from(Pathname.new(Folders[:website])).to_s
					#ext = File.extname(addedfile)  

					puts ""
					puts "***********************************************"
					puts "  Added: #{addedfile}"
					puts "***********************************************"
					puts ""

					if addedfile.start_with?('_pages/')
						buildfile = true
					end
				}
			end

			if modified.length > 0
				modified.each{|filename|
					modifiedfile = Pathname.new(filename).relative_path_from(Pathname.new(Folders[:website])).to_s
					ext = File.extname(modifiedfile)  

					puts ""
					puts "***********************************************"
					puts "  Modified: #{modifiedfile}"
					puts "***********************************************"
					puts ""

					buildfile = true

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
			end

			Scms.sassall(Folders[:website]) if sassfile
			Scms.bundle(settings, Folders[:website]) if bundlefile
			Scms.build(Folders[:website], settings, options[:mode], options[:watch]) if buildfile
	    end

	    listener.start # not blocking
	    listener.ignore! /\.png/
	    listener.ignore! /\.gif/
	    listener.ignore! /\.jpg/
    end
end

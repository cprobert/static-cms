module ScmsWatcher
	require 'fileutils'
	require 'filewatcher'
	require 'pathname'
	require 'listen'

    def ScmsWatcher.watch(settings, options, configdir)
	    # File watching
	    watcher = Thread.new {
	    	files = []
	    	Dir.glob('**/*.scss').each do|f|
				files << f
			end
			Dir.glob('**/*.bundle').each do|f|
				files << f
			end
			files << "_config.yml"

			FileWatcher.new(files).watch do |filename|
				ext = File.extname(filename)  

				begin
					case ext
					when ".scss"
						puts ""
						puts "***********************************"
						puts " Sass file changed: #{filename}"
						puts "***********************************"
						puts ""
						Scms.sass(filename)
						#Scms.sassall(Folders[:website])
					when ".yml"
						puts ""
						puts "******************************************************"
						puts " Config Modification #{filename} "
						puts "******************************************************"
						puts ""
						settings = Scms.getSettings(configdir)
						Scms.bundle(settings, Folders[:website])
						Scms.build(Folders[:website], settings, options)
					when ".bundle"
						puts ""
						puts "******************************************************"
						puts " Bundle Modified: #{filename} "
						puts "******************************************************"
						puts ""
						Scms.bundler(filename)
					end
				rescue Exception=>e
	                ScmsUtils.errLog(e.message)
	                ScmsUtils.log(e.backtrace.inspect)
				end
			end
	    }

		folders = []
	    Dir.glob('*').select { |fn| File.directory?(fn) and (fn.match(/^_/) ) }.each do|f|
			folders.push(f) 
		end
	    puts "Listening to #{folders}"
	    listener = Listen.to(folders, force_polling: true) do |modified, added, removed|

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
					#ext = File.extname(modifiedfile)  

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
				}
			end

			begin
				Scms.sassall(Folders[:website]) if sassfile
				Scms.bundle(settings, Folders[:website]) if bundlefile
				Scms.build(Folders[:website], settings, options) if buildfile
			rescue Exception=>e
                ScmsUtils.errLog(e.message)
                ScmsUtils.log(e.backtrace.inspect)
			end

	    end

	    listener.start # not blocking
	    listener.ignore! /\.png/
	    listener.ignore! /\.gif/
	    listener.ignore! /\.jpg/
    end
end

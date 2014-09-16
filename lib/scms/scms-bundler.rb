module ScmsBundler
    require 'fileutils'
    require 'packr'
    require 'scms/scms-bundler.rb'
    require 'zlib'

    def ScmsBundler.run()
		Dir.glob('**/*.bundle').each do|bundle|
			ScmsBundler.bundle(bundle)
		end
    end

    def ScmsBundler.bundle(bundle)
    	puts "Parsing bundle: #{bundle}"

    	content = ""
		if File::exists?(bundle)
			wd = File.dirname(bundle)
            

			File.readlines(bundle).each do |line|
				bundleFile = line.strip
				bundleFile = bundleFile.gsub('\n', '')

				next  if bundleFile == nil
				next  if bundleFile == ""
				next if line.match(/^generate:/)

				if !line.match(/^#/)
					b = File.join(wd, bundleFile)
					puts "Including: #{line}"
					if File::exists?(b)
						fileContents = File.read(b)

						if File.extname(b) == ".js"
							if b.include? ".fat."
	                        	puts "Minifing: #{b}"
	                        	fileContents = Packr.pack(fileContents) unless /(-min)|(\.min)|(\-pack)|(\.pack)/.match(b)
	                    	end
						end

						content += fileContents + "\n"
					else
						puts "Can not read: #{b}"
					end
				end
			end

			out = ScmsBundler.getGeneratedBundleName(bundle)
			begin
                File.open(out, 'w') {|f| f.write(content) }
                ScmsUtils.successLog("Created: #{out}")

                extn = File.extname  out        # => ".mp4"
				name = File.basename out, extn  # => "xyz"
				path = File.dirname  out        # => "/path/to"
				
				gzip_out = File.join(path, "#{name}.gz#{extn}")
				Zlib::GzipWriter.open(gzip_out) do |gz|
					File.open(out).each do |line|
						gz.write line
					end
					gz.close
				end
				#puts "Created gzip: #{gzip_out}"
			rescue Exception=>e
                ScmsUtils.errLog("Error creating gzip version of bundle: #{gzip_out}")
                ScmsUtils.errLog(e.message)
                ScmsUtils.log(e.backtrace.inspect)
			end
		end
    end

    def ScmsBundler.watch()
    	# Listen to changes to files withing a bundle
	    Dir.glob('**/*.bundle').each do|bundle|
			ScmsBundler.watchBundle(bundle)
		end	
    end

    def ScmsBundler.watchBundle(bundle)
    	files = ScmsBundler.getBundleFiles(bundle)
    	Thread.new {
			FileWatcher.new(files).watch do |filename|
				begin
					ScmsBundler.bundle(bundle)
				rescue Exception=>e
	                ScmsUtils.errLog(e.message)
	                ScmsUtils.log(e.backtrace.inspect)
				end
			end
    	}
    end

    def ScmsBundler.getBundleFiles(bundle)
    	files = []
		if File::exists?(bundle)
			wd = File.dirname(bundle)
			File.readlines(bundle).each do |line|
				bundleFile = line.strip
				bundleFile = bundleFile.gsub('\n', '')

				next  if bundleFile == nil
				next  if bundleFile == ""
				next if line.match(/^generate:/)

				if !line.match(/^#/)
					b = File.join(wd, bundleFile)
					if File::exists?(b)
						files << b
					end
				end
			end
		end
		return files
    end

	def ScmsBundler.toStub(bundle)
		return bundle.gsub(".bundle", "")
	end

    def ScmsBundler.getGeneratedBundleName(bundle)
		name = ScmsBundler.toStub(bundle)

		if File::exists?(bundle)
			wd = File.dirname(bundle)
			File.readlines(bundle).each do |line|
				if line.match(/^generate:/)
					name = File.join(wd, line.gsub("generate:", "").strip)
					break
				end
			end
		end
    	return name
    end
end
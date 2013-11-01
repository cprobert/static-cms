module ScmsBundler
    require 'fileutils'

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
            out = bundle.gsub(".bundle", "")

			File.readlines(bundle).each do |line|
				bundleFile = line.strip
				bundleFile = bundleFile.gsub('\n', '')

				next  if bundleFile == nil
				next  if bundleFile == ""

				if line.match(/^generate:/)
					out = File.join(wd, line.gsub("generate:", "").strip)
					next
				end

				if !line.match(/^#/)
					b = File.join(wd, bundleFile)
					puts "Including: #{line}"
					if File::exists?(b)
						content +=  File.read(b) + "\n"
					else
						puts "Can not read: #{b}"
					end
				end
			end

			begin
                File.open(out, 'w') {|f| f.write(content) }
                ScmsUtils.successLog("Created: #{out}")
			rescue Exception=>e
                ScmsUtils.errLog("Error creating bundle: #{out}")
                ScmsUtils.errLog(e.message)
                ScmsUtils.log(e.backtrace.inspect)
			end
		end
    end
end
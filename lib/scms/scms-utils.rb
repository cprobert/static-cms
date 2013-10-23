module ScmsUtils
    require 'find'
    require 'fileutils'
    require 'open-uri'

    require 'socket'
    require 'timeout'

    def ScmsUtils.port_open?(ip, port, seconds=1)
      Timeout::timeout(seconds) do
        begin
          TCPSocket.new(ip, port).close
          true
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
          false
        end
      end
    rescue Timeout::Error
      false
    end

    def ScmsUtils.readyaml(yamlpath)
        config = nil
        if File.exist?(yamlpath)
            tree = File.read(yamlpath)
            begin
                myconfig = ERB.new(tree).result()
                #puts "Conf = #{myconfig}"
                config = YAML.load(myconfig)
                #config = YAML.load_file(yamlpath)
            rescue Exception => e  
                ScmsUtils.errLog("Error Loading _config.yml (check there are no tabs in the file)")
                ScmsUtils.log("Yaml: #{ScmsUtils.uriEncode("file:///#{yamlpath}")}")
                ScmsUtils.log( "Verify your config")
                ScmsUtils.log( "http://yaml-online-parser.appspot.com/")
                ScmsUtils.errLog( e.message )
                ScmsUtils.errLog( e.backtrace.inspect )
            end
        else
            ScmsUtils.errLog("Config file does not exist: #{yamlpath}")
        end
        
        return config
    end

    def ScmsUtils.run(cmd, params)
        if system("#{cmd} #{params}")
            ScmsUtils.successLog( "#{cmd} ran successfully" )
        else
            raise "Error running #{cmd}"
        end
    end
    
    def ScmsUtils.errLog(msg)
        if !msg.nil?
            if ENV["SCMS_HTML_OUT"] == "true"
                puts "<div style='color: red;'>#{ScmsUtils.txt_2_html(msg)}</div>"
            else
                puts msg
            end
        end
    end
    
    def ScmsUtils.successLog(msg)
        if !msg.nil?
            if ENV["SCMS_HTML_OUT"] == "true"
                puts "<div style='color: green;'>#{ScmsUtils.txt_2_html(msg)}</div>"
            else
                puts msg
            end
        end
    end
    
    def ScmsUtils.boldlog(msg)
        if !msg.nil?
            if ENV["SCMS_HTML_OUT"] == "true"
                puts "<strong>#{ScmsUtils.txt_2_html(msg)}</strong>"
            else
                puts msg
            end
        end
    end

    def ScmsUtils.log(msg)
        if !msg.nil?
            if ENV["SCMS_HTML_OUT"] == "true"
                puts "<div>#{ScmsUtils.txt_2_html(msg)}</div>"
            else
                puts msg
            end
        end
    end
    
	def ScmsUtils.writelog(log, pub)
        if !pub.nil? && !log.nil? 
            open(File.join(pub, "_build.log"), 'a') { |f|
              f.puts log
            }
        end
	end
    
	def ScmsUtils.txt_2_html(rawsnippet)
		if rawsnippet != nil
			rawsnippet.gsub!(/(http:\/\/\S+)/, '<a href="\1" target="_blank" ref="external">\1</a>')
            rawsnippet.gsub!(/(file:\/\/\/\S+)/, '<a href="\1" target="_blank" ref="external">\1</a>')
			rawsnippet.gsub!(/\n/, "<br />")
		end
		
		return rawsnippet
	end
    
    def ScmsUtils.uriEncode(uri)
        return uri.gsub(" ", "%20")
    end
    
    def ScmsUtils.uriDecode(uri)
        return uri.gsub("%20", " ")
    end
    
end


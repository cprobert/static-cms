module ScmsUtils
    require 'find'
    require 'fileutils'
    require 'open-uri'

    def ScmsUtils.run(cmd, params)
        if system("#{cmd} #{params}")
            ScmsUtils.successLog( "#{cmd} ran successfully" )
        else
            raise "Error running #{cmd}"
        end
    end
    
    def ScmsUtils.errLog(msg)
        if !msg.nil?
            if $html == "true"
                puts "<div style='color: red;'>#{ScmsUtils.txt_2_html(msg)}</div>"
            else
                puts msg
            end
        end
    end
    
    def ScmsUtils.successLog(msg)
        if !msg.nil?
            if $html == "true"
                puts "<div style='color: green;'>#{ScmsUtils.txt_2_html(msg)}</div>"
            else
                puts msg
            end
        end
    end
    
    def ScmsUtils.log(msg)
        if !msg.nil?
            if $html == "true"
                puts "<div>#{ScmsUtils.txt_2_html(msg)}</div>"
            else
                puts msg
            end
        end
    end
    
	def ScmsUtils.writelog(pub, log)
        if !pub.nil? && !log.nil? 
            open(File.join(pub, "build.log"), 'a') { |f|
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
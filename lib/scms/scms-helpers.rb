module ScmsHelpers
    require 'find'
    
    def ScmsHelpers.isActive(pagename, activepage)
        return active = "active" if activepage == pagename
    end

    def ScmsHelpers.isActiveIfContains(pagename, activepage)
        return active = "active" if activepage.include? pagename
    end

	def ScmsHelpers.txt_2_html(rawsnippet)
		if rawsnippet != nil
			rawsnippet.gsub!(/(http:\/\/\S+)/, '<a href="\1" target="_blank" ref="external">\1</a>')
            rawsnippet.gsub!(/(file:\/\/\/\S+)/, '<a href="\1" target="_blank" ref="external">\1</a>')
			rawsnippet.gsub!(/\n/, "<br />")
		end
		
		return rawsnippet
	end
    
    def ScmsHelpers.uriEncode(uri)
        return uri.gsub(" ", "%20")
    end
    
    def ScmsHelpers.uriDecode(uri)
        return uri.gsub("%20", " ")
    end
    
end


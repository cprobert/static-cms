module ScmsXmlHandler
	VERSION = '1.0.0'
	require 'nokogiri'
	
	def ScmsXmlHandler.transform(xmlstring)

		# This could be a better solution: http://stackoverflow.com/questions/3542264/can-nokogiri-search-for-xml-stylesheet-tags

		xml = Nokogiri::XML(xmlstring)
		#<?xml-stylesheet type="text/xsl" href="../skins/html5-boilerplate.xsl"?>
		pi = xml.children[0]
		mypi = pi.to_s.scan(/.* href="(.*)"\?>/)
		
		if mypi[0] != nil
			xslpi = mypi[0][0].to_s
			puts "Transforming with #{xslpi}"
			xslpi = File.join($website, xslpi)
			
			if File.exists?(xslpi)
				xsl = File.read(xslpi)
				xslt  = Nokogiri::XSLT(xsl)
				return xslt.transform(xml).to_html
			else
				puts "Cant find pi: #{xslpi}"
			end
		else
			puts "No XSL processing instruction found in #{view}"
		end

		return xmlstring

	end
end
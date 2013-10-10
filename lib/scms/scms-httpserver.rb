require 'webrick'
require 'launchy'

module ScmsServer
	include WEBrick

	def ScmsServer.start(port, root_document)

		puts "Starting server: http://#{Socket.gethostname}:#{port}"
		#:BindAddress
		server = HTTPServer.new(:Port=> port, :DocumentRoot=> root_document)
		mime_types_file = File.expand_path('../../assets/mime.types', File.dirname(__FILE__))
		puts mime_types_file
		WEBrick::HTTPUtils::load_mime_types(mime_types_file)

		trap("INT"){ 
		  puts "Closed http server"
		  server.shutdown
		  exit!
		}

		uri = "http://localhost:#{port}"
		Launchy.open( uri ) do |exception|
		  puts "Attempted to open #{uri} and failed because #{exception}"
		end

		server.start

		return server
	end

end
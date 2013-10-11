require 'webrick'
require 'launchy'

module ScmsServer
	include WEBrick

	def ScmsServer.start(root_document, port, hostname="localhost")

		puts "Starting server: http://#{hostname}:#{port}"
		#:BindAddress
		server = HTTPServer.new(
			:DocumentRoot => root_document,
			:Port => port, 
			:BindAddress => hostname
		)

		mime_types_file = File.expand_path('../../assets/mime.types', File.dirname(__FILE__))
		WEBrick::HTTPUtils::load_mime_types(mime_types_file)

		trap("INT"){ 
		  puts "Closed http server"
		  server.shutdown
		  exit!
		}

		uri = "http://#{hostname}:#{port}"
		Launchy.open( uri ) do |exception|
		  puts "Attempted to open #{uri} and failed because #{exception}"
		end

		begin
			server.start
		rescue SystemExit, Interrupt
			puts "Closing web brick"
			server.start
		rescue StandardError => e
			puts "StandardError"
			server.shutdown
		rescue Exception => e
			puts "scms-server exception"
			rais e
		end
	end

end
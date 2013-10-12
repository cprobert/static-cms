require 'webrick'
require 'launchy'
require "scms/scms-utils.rb"

module ScmsServer
	include WEBrick

	def ScmsServer.start(root_document, port, hostname="localhost")

		portopen = ScmsUtils.port_open? hostname, port
		puts "Port Open: #{portopen}"

		if !portopen
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
			  #exit!
			}
		else
			puts "Server already running on port: #{port}"
		end

		uri = "http://#{hostname}:#{port}"
		Launchy.open( uri ) do |exception|
		  puts "Attempted to open #{uri} and failed because #{exception}"
		end

		if !portopen
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

end
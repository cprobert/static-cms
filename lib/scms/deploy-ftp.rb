require 'fileutils'
require 'scms/extensions.rb'
require 'scms/scms-utils.rb'

module FtpDeploy
  
  # yml file example:

  # host: localhost
  # port: 21
  # username: exampleuser
  # password: seCre7Squr1al
  # passive: true
  # directory: /htdocs

  def FtpDeploy.sync(website, config)

    ftpYamlPath=File.join(config, "_ftpconfig.yml")
    settings = YAML.load_file(ftpYamlPath)
    throw "No gost defined in _ftpconfig.yml settings file" if settings['host'] == nil

    host = settings['host']
    port = (settings['port'] || 21).to_i
    passive  = settings['passive'] || true
    remote_dir = settings['directory'] || "/"

    ScmsUtils.boldlog("Sending site over FTP (host: #{host}, port: #{port})")
    begin
      if settings['username'].nil?
        print "FTP Username: "
        username = $stdin.gets.chomp
      else
        username = settings['username']
      end

      if settings['password'].nil?
        print "FTP Password: "
        # We hide the entered characters before to ask for the password
        system "stty -echo"
        password = $stdin.gets.chomp
        system "stty echo"
      else
        password = settings['password']
      end
    rescue NoMethodError, Interrupt
      # When the process is exited, we display the characters again
      # And we exit
      system "stty echo"
      exit
    end

    ftp = FtpDeploy::Ftp.new(host, port, {:username => username, :password => password, :passive => passive})
    puts "\r\nConnected to server. Sending site"
    ftp.sync(website, remote_dir)
    puts "Successfully published site"
  end

  class Ftp
    require 'net/ftp'

    attr_reader :host, :port, :username, :password, :passive

    def initialize(host, port = 21, options = Hash.new)
      options = {:username => nil, :password => nil}.merge(options)
      @host, @port = host, port
      @username, @password = options[:username], options[:password]
      @passive = options[:passive]
    end

    def sync(local, distant)
      connect do |ftp|
        send_dir(ftp, local, distant)
      end
    end

    private
    def connect
      begin
        Net::FTP.open(host) do |ftp|
          ftp.passive = @passive
          #ftp.debug_mode = true
          ftp.connect(host, port)
          ftp.login(username, password)
          puts ftp.welcome
          yield ftp
        end
      rescue Exception=>e
        ScmsUtils.errLog(e.message)
        ScmsUtils.log(e.backtrace.inspect)
      end
    end

    def send_dir(ftp, local, distant)
      begin
        ftp.mkdir(distant)
      rescue Net::FTPPermError
        # We don't do anything. The directory already exists.
        # TODO : this is also risen if we don't have write access. Then, we need to raise.
      end
      Dir.foreach(local) do |file_name|
        
        # If the file/directory is hidden (first character is a dot), we ignore it
        next if file_name =~ /^(\.|\.\.)$/
        next if file_name =~ /^(\.)/
        next if file_name =~ /^_/

        #puts file_name

        if ::File.stat(local + "/" + file_name).directory?
          # It is a directory, we recursively send it
          begin
            ftp.mkdir(distant + "/" + file_name)
          rescue Net::FTPPermError
            # We don't do anything. The directory already exists.
            # TODO : this is also risen if we don't have write access. Then, we need to raise.
          end
          send_dir(ftp, local + "/" + file_name, distant + "/" + file_name)
        else
           # It's a file, we just send it
           localFilePath = local + "/" + file_name
           remoteFilePath = distant + "/" + file_name

           if File.binary?(local + "/" + file_name)
             puts "#{file_name} (binary)"
             ftp.putbinaryfile(localFilePath, remoteFilePath)
           else
             puts "#{file_name} (text)"
             ftp.puttextfile(localFilePath, remoteFilePath)
           end
        end
      end
    end

    private
    def host_with_port
      "#{host}:#{port}"
    end
  end
end

require 'net/ftp'
require 'fileutils'

require 'scms/extentions.rb'
require 'scms/scms-utils.rb'

module FtpDeploy
  

  def FtpDeploy.sync(options)
    ftp_port = (options['ftp_port'] || 21).to_i
    passive  = options['ftp_passive'] || true

    puts "Sending site over FTP (host: #{options['ftp_host']}, port: #{ftp_port})"
    begin
      if options['ftp_username'].nil?
        print "FTP Username: "
        username = $stdin.gets.chomp
      else
        username = options['ftp_username']
      end

      if options['ftp_password'].nil?
        print "FTP Password: "
        # We hide the entered characters before to ask for the password
        system "stty -echo"
        password = $stdin.gets.chomp
        system "stty echo"
      else
        password = options['ftp_password']
      end
    rescue NoMethodError, Interrupt
      # When the process is exited, we display the characters again
      # And we exit
      system "stty echo"
      exit
    end

    ftp = FtpDeploy::Ftp.new(options['ftp_host'], ftp_port, {:username => username, :password => password, :passive => passive})
    puts "\r\nConnected to server. Sending site"
    ftp.sync(options['source'], options['ftp_dir'])
    puts "Successfully sent site"
  end

  class Ftp
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
        next if file_name =~ /^(_)$/

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
           if File.join(local + "/" + file_name).binary?
             puts "#{file_name} (binary)"
             ftp.putbinaryfile(local + "/" + file_name, distant + "/" + file_name)
           else
             puts "#{file_name} (text)"
             localFilePath = local + "/" + file_name
             remoteFilePath = distant + "/" + file_name
             puts "localFilePath: #{localFilePath}"
             puts "remoteFilePath: #{remoteFilePath}"
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

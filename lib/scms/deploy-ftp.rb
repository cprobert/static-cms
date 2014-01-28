require 'net/ftp'

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
    ftp.sync(options['destination'], options['ftp_dir'])
    puts "Successfully sent site"
  end

  class File

    def self.is_bin?(f)
      file_test = %x(file #{f})

      # http://stackoverflow.com/a/8873922
      file_test = file_test.encode('UTF-16', 'UTF-8', :invalid => :replace, :replace => '').encode('UTF-8', 'UTF-16')

      file_test !~ /text/
    end
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
      Net::FTP.open(host) do |ftp|
        ftp.passive = @passive
        ftp.connect(host, port)
        ftp.login(username, password)
        yield ftp
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
           if FtpDeploy::File.is_bin?(local + "/" + file_name)
             ftp.putbinaryfile(local + "/" + file_name, distant + "/" + file_name)
           else
             ftp.puttextfile(local + "/" + file_name, distant + "/" + file_name)
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

class File

  # def self.is_bin?(f)
  #   file_test = %x(file #{f})

  #   # http://stackoverflow.com/a/8873922
  #   file_test = file_test.encode('UTF-16', 'UTF-8', :invalid => :replace, :replace => '').encode('UTF-8', 'UTF-16')

  #   file_test !~ /text/
  # end

  def File.binary? name
    open name do |f|
      while (b=f.read(256)) do
        return true if b[ "\0"]
      end
    end
    false
  end

end
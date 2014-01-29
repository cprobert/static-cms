class File
  def self.binary?(name)
    ascii = control = binary = 0

    File.open(name, "rb") {|io| io.read(1024)}.each_byte do |bt|
      case bt
        when 0...32
          control += 1
        when 32...128
          ascii += 1
        else
          binary += 1
      end
    end

    control.to_f / ascii > 0.1 || binary.to_f / ascii > 0.05
  end
end
module Yui
    def Yui.eatall(crunchDir)
        ScmsUtils.log( "Starting crunching CSS and JavaScript in:\n#{crunchDir}\n\n" )
        Dir.chdir(crunchDir) do
            Dir.glob("**/*.{css, js}").each do |asset|
                #fullFileName = File.basename(asset)
                #ScmsUtils.log( "Crunching #{fullFileName}" )
                ext = File.extname(asset)
                Yui.compress(asset, ext)
            end
        end
    end 

    def Yui.compress(asset, ext)
        if File.exists?(asset)
            #ScmsUtils.log( " Encoding: #{asset.encoding}" )
            enc = "--charset utf-8"
            enc = ""
            cmd = "java"
            params = "-jar \"#{File.join(Folders[:assets], "yuicompressor", "yuicompressor-2.4.7.jar")}\"  #{enc} --type #{ext.gsub(".","")} \"#{asset}\" -o \"#{asset}\""
            ##Need to check if asset exists
            if system("#{cmd} #{params}")
                ScmsUtils.log( "_Crunched #{File.basename(asset)}_" )
            else
                ScmsUtils.errLog( "Error crunching: #{asset}" )
            end
        else
            ScmsUtils.errLog( "#{asset} does not exist" )
        end
    end
end
require "scms/version"

module Scms
    require 'scms/scms-utils.rb'
    require 'scms/s3deploy.rb'

    require 'erb'
    require 'ostruct' 
    require 'yaml'
    require 'sass'
    require 'packr'
    require 'maruku'
    
    include YAML
    
    def Scms.build(pub, config, mode)
        @pub = $website
        @cleanpub = false
        if pub != nil
            @pub = pub 
            @cleanpub = true
        end

        @configdir = config
        @mode = mode
        #ScmsUtils.log("Mode: #{mode}")
        
        @source = File.join($website)
        # Support for legacy publick folders
        if (Dir.exists? File.join($website, "public"))
            @source =  File.join($website, "public")
            @pub = File.join($website, "_site") if pub == nil
        end
        
        ScmsUtils.log("Source #{@source}")
        Scms.sassall(@source)
        
        yamlpath=File.join(@configdir, "_config.yml")
        ScmsUtils.log("Loading Config: #{ScmsUtils.uriEncode("file:///#{yamlpath}")}")
        $settings = Scms.getsettings(yamlpath)
        if $settings
            if $settings["options"] != nil
                # Don't overwrite environment settings
                if ENV["SCMS_PUBLISH_FOLDER"] == nil && $settings["options"]["build_dir"] != nil
                    ScmsUtils.log("_Getting pub dir from _config.yml_")
                    @pub = $settings["options"]["build_dir"]
                end
                if $settings["options"]["clean_build_dir"] == true
                    ScmsUtils.log("Cleaning build dir")
                    @cleanpub = true
                end
            end
            
            if @cleanpub
                Scms.cleanpubdir(@pub)
                @cleanpub = false
            end
            
            #Bootstrap here
            if $settings["bootstrap"] != nil
                bootstrap = File.join($website, $settings["bootstrap"])
                #ScmsUtils.log("Bootstrap is: #{$settings["bootstrap"]}")
                if File.exists?(bootstrap)
                    begin
                        require_relative bootstrap
                    rescue Exception=>e
                        ScmsUtils.errLog( e )
                    end
                else
                    ScmsUtils.log("_Bootstrap does not exist #{bootstrap}_")
                end
            end 
            
            #Bundle resources
            scripts = Scms.bundlescripts($settings["scripts"])
            stylesheets = Scms.bundlestylesheets($settings["stylesheets"])
            #Generate pages
            Scms.parsepages(scripts, stylesheets)
        else
            ScmsUtils.errLog("Config is empty")
        end
        
        if @pub != $website
            ScmsUtils.log("Merging 'public' folder")
            
            Scms.cleanpubdir(@pub) if @cleanpub
            FileUtils.mkdir @pub unless Dir.exists? @pub
            Dir.chdir(@source) do
                #files = Dir.glob('*')
                #FileUtils.cp_r files, @pub            
                
                Dir.glob("**/*").reject{|f| f['.svn']}.each do |oldfile|
                  newfile = File.join(@pub, oldfile.sub(@source, ''))
                  #puts newfile
                  File.file?(oldfile) ? FileUtils.copy(oldfile, newfile) : FileUtils.mkdir(newfile) unless File.exist? newfile
                end
            end
        end
        
        ScmsUtils.log(ScmsUtils.uriEncode("file:///#{@pub}"))
        return @pub
    end
    
    def Scms.parsepages(scripts, stylesheets)
        # build views from templates
        @template = $settings["template"] 
        if $settings["pages"] != nil
            ScmsUtils.log("Compiling Pages:")
            $settings["pages"].each do |page|
                if page != nil
                    page.each do |option|
                        #ScmsUtils.log( "option (#{option.class}) = #{option[0]}" )
                        pageconfig = option[1]
                        #ScmsUtils.log( "Pageconfig = #{pageconfig}" )
                        
                        if pageconfig["template"] == nil
                            skin = @template
                        else
                            skin = pageconfig["template"]
                        end
                        
                        page = pageconfig["generate"]
                        ScmsUtils.successLog("#{page}")
                        
                        resource = Hash.new
                        if pageconfig["resource"] != nil
                            resourcepath = File.join($website, pageconfig["resource"])
                            if File.exists?(resourcepath)
                                #ScmsUtils.log( "_Resource found: #{pageconfig["resource"]}_" )
                                resource = YAML.load_file(resourcepath)
                            else
                                ScmsUtils.errLog( "Resource not found: #{resourcepath}" )
                            end
                        end
                        
                        hasHandler = "no"
                        if pageconfig["handler"] != nil
                            handlerpath = File.join($website, pageconfig["handler"])
                            if File.exists?(handlerpath)
                                #ScmsUtils.log( "Handler found: #{pageconfig["handler"]}" )
                                require handlerpath
                                funDefined = defined? Handler.render
                                if funDefined != nil
                                    hasHandler = "yes"
                                else
                                    ScmsUtils.errLog( "Handler doesnt have a render method" )
                                end
                            else
                                ScmsUtils.errLog( "**Handler not found: #{handlerpath}**" )
                            end
                        end
                        
                        views = Hash.new
                        pageconfig["views"].each do |view| 
                            views[view[0]] = ""
                            viewpath = File.join($website, view[1])
                            if File.exists?(viewpath)
                                htmlsnipet = File.read(viewpath)
                                if !htmlsnipet.empty?
                                    model = Hash.new
                                    model = { :page => page, :sitedir => $website, :resource => resource }
                                    if hasHandler == "yes"
                                        ScmsUtils.log("Rendering with handler")
                                        viewSnippet = Handler.render(viewpath)
                                    else
                                        snnipetCode = File.read(viewpath)
                                        case File.extname(view[1])
                                        when ".md"
                                            begin  
                                                doc = Maruku.new(snnipetCode)
                                                viewSnippet = doc.to_html
                                            rescue Exception => e  
                                                viewSnippet = snnipetCode
                                                puts e.message  
                                                puts e.backtrace.inspect  
                                            end
                                        else
                                          viewSnippet = snnipetCode
                                        end
                                    end
                                    
                                    if @mode == "cms"
                                        views[view[0]] = "<div class='cms' data-view='#{view[1]}' data-page='#{page}'>#{Scms.parsetemplate(viewSnippet, model)}</div>"
                                    else
                                        views[view[0]] = Scms.parsetemplate(viewSnippet, model)
                                    end
                                else
                                    ScmsUtils.writelog(@pub, "Empty file: #{viewpath}")
                                end
                            else
                                ScmsUtils.errLog("View not found: #{view[0]} - #{view[1]} [#{viewpath}]")
                                ScmsUtils.writelog(@pub, "View not found: #{view[0]} - #{view[1]} [#{viewpath}]")
                            end
                            #ScmsUtils.log( "view = #{view[0]} - #{view[1]}" )
                        end
                        
                        monkeyhook = "";
                        if @mode == "cms"
                            monkeyhook = "<script src='scripts/air-monkey-hook.js'></script>"
                        end
                        
                        hash = { 
                            :page => page, 
                            :views => views, 
                            :resource => resource, 
                            :config => pageconfig, 
                            :scripts => scripts, 
                            :stylesheets => stylesheets, 
                            :sitedir => $website, 
                            :monkeyhook => monkeyhook 
                        }
                        
                        erb = File.join($website, skin)
                        out = File.join(@pub, pageconfig["generate"])
                        
                        if File.exists?(erb)
                            pubsubdir = File.dirname(out)
                            Dir.mkdir(pubsubdir, 755) unless File::directory?(pubsubdir)
                            html = Scms.parsetemplate(File.read(erb), hash)
                            File.open(out, 'w') {|f| f.write(html) }
                        else
                            ScmsUtils.errLog("Template doesn't exist: #{erb}")
                        end
                    end
                end
                #ScmsUtils.log( out )
            end
        end
    end

    def Scms.bundlescripts(scriptsConfig)
        scripts = Hash.new
        if scriptsConfig != nil
            ScmsUtils.log("Bundeling Scripts:")
            scriptsConfig.each do |script|
                #ScmsUtils.log( "script (#{script.class}) = #{script}" )
                script.each do |option|
                    name = option[0]
                    if option[1]["version"] != nil
                        scriptversion = option[1]["version"]
                    else
                        scriptversion = 1
                    end
                    scriptname = File.join("scripts", "#{name}-v#{scriptversion}.js") #Legasy name filename from root and version
                    scriptname = File.join(option[1]["generate"]) if option[1]["generate"] != nil #just use the generate
                    scriptsdir = File.dirname(scriptname)
                    Dir.mkdir(scriptsdir, 755) unless File::directory?(scriptsdir)

                    ScmsUtils.successLog("#{scriptname}")
                    content = ""
                    
                    assetList = ""
                    bundle = option[1]["bundle"]
                    bundle.each do |asset|
                        assetList += "\t#{asset}\n" 
                        assetname = File.join(@source, asset)
                        if File::exists?(assetname)
                            content = content + "\n" + File.read(assetname)
                        else
                            ScmsUtils.errLog( "Error: No such file #{assetname}" )
                        end
                    end
                    ScmsUtils.log("#{assetList}")
                    
                    scripts[name] = scriptname
                    File.open(scriptname, 'w') {|f| f.write(content) }
                    Scms.packr(scriptname) unless /(-min)|(\.min)/.match(scriptname)
                end
            end
        end
        return scripts
    end
    
    def Scms.bundlestylesheets(styleConfig)
        stylesheets = Hash.new
        if styleConfig != nil
            ScmsUtils.log("Bundeling Stylesheets:")
            styleConfig.each do |stylesheet|
                #ScmsUtils.log( "stylesheet (#{stylesheet.class}) = #{stylesheet}" )
                stylesheet.each do |option|
                    name = option[0]
                    if option[1]["version"] != nil
                        stylesheetversion = option[1]["version"]
                    else
                        stylesheetversion = 1
                    end
                    stylesheetname = File.join("stylesheets", "#{name}-v#{stylesheetversion}.css") #Legasy name filename from root and version
                    stylesheetname = File.join(option[1]["generate"]) if option[1]["generate"] != nil #just use the generate
                    stylesheetdir = File.dirname(stylesheetname)
                    Dir.mkdir(stylesheetdir, 755) unless File::directory?(stylesheetdir)
                    
                    ScmsUtils.successLog("#{stylesheetname}")
                    content = ""
                    
                    bundle = option[1]["bundle"]
                    assetList = ""
                    bundle.each do |asset|
                        assetList += "\t #{asset}\n" 
                        assetname = File.join(@source, asset)
                        if File::exists?(assetname)
                            content = content + "\n" + File.read(assetname)
                        else
                            ScmsUtils.errLog( "Error: No such file #{assetname}" )
                        end
                    end
                    ScmsUtils.log( "#{assetList}" )
                    
                    stylesheets[name] = stylesheetname
                    File.open(stylesheetname, 'w') {|f| f.write(content) }
                end
            end
        end 
        return stylesheets
    end
    
    def Scms.parsetemplate(template, hash)
        data = OpenStruct.new(hash)
        result = ""
        
        begin 
            result = ERB.new(template).result(data.instance_eval { binding })
        rescue Exception => e  
                    ScmsUtils.errLog("**Critical Error: Could not parse template**")
                    ScmsUtils.log( "_(if your using resources make sure their not empty)_" )
                    ScmsUtils.errLog( e.message )
        end
        
        return result
    end

    def Scms.getsettings(yamlpath)
        config = nil
        
        if File.exist?(yamlpath)
            tree = File.read(yamlpath)
            begin
                myconfig = ERB.new(tree).result()
                #puts "Conf = #{myconfig}"
                config = YAML.load(myconfig)
                #config = YAML.load_file(yamlpath)
            rescue Exception => e  
                ScmsUtils.errLog("Error Loading _config.yml (check there are no tabs in the file)")
                ScmsUtils.log( "_[Verify your config](http://yaml-online-parser.appspot.com/)_")
                ScmsUtils.errLog( e.message )
                ScmsUtils.errLog( e.backtrace.inspect )
            end
        else
            ScmsUtils.errLog("Config file does not exist: #{yamlpath}")
        end
        
        return config
    end
    
    def Scms.cleanpubdir(pub)
        ScmsUtils.log("_Cleaning pub folder #{pub}_")
        FileUtils.rm_rf pub
        #FileUtils.remove_dir(pub, force = true)
        sleep 0.5 # seconds
        FileUtils.mkdir_p(pub) unless File.exist? pub
        FileUtils.chmod 0755, pub
    end
    
    def Scms.crunch(crunchDir)
        ScmsUtils.log( "Starting crunching CSS and JavaScript in:\n#{crunchDir}\n\n" )
        #Scms.sassall(crunchDir)
        Dir.chdir(crunchDir) do
            Dir.glob("**/*.js").reject{|f| /-min/.match(f) != nil || /\.min/.match(f) != nil || /\.pack/.match(f) != nil }.each do |asset|
                Scms.packr(asset)
            end
            #Dir.glob("**/*.{css, js}").each do |asset|
            #    #fullFileName = File.basename(asset)
            #    #ScmsUtils.log( "Crunching #{fullFileName}" )
            #    ext = File.extname(asset)
            #    Scms.yuicompress(asset, ext)
            #end
        end
    end

    def Scms.sassall(crunchDir)
        ScmsUtils.log("Minimising Sass Files (.scss)")
        Dir.chdir(crunchDir) do
            Dir.glob("**/*.{scss}").each do |asset|
                Scms.sass(asset)
            end
        end
    end

    def Scms.sass(asset)
        if File.exists?(asset)
            begin
                template = File.read(asset)
                sass_engine = Sass::Engine.new(template, {
                                                          :style => :compressed,
                                                          :cache => false,
                                                          :syntax => :scss
                                                         }.freeze)
                output = sass_engine.to_css
                css_file = "#{File.dirname(asset)}/#{File.basename(asset,'.*')}.css"
                File.open(css_file, 'w') { |file| file.write(output) }
                ScmsUtils.log( "_Sassed: #{css_file}_" )
            rescue Exception => e  
                ScmsUtils.errLog( "Error processing: #{asset}" )
                ScmsUtils.errLog( e.message )
            end
        end
    end
    
    def Scms.packr(asset)
        if File.exists?(asset)
            begin
                code = File.read(asset)
                compressed = Packr.pack(code)
                File.open(asset, 'w') { |f| f.write(compressed) }
                ScmsUtils.log( "Minified #{File.basename(asset)}" )
            rescue Exception => e  
                ScmsUtils.errLog( "Error processing: #{asset}" )
                ScmsUtils.errLog( e.message )
            end
        end
    end
        
    def Scms.yuicompress(asset, ext)
        if File.exists?(asset)
            #ScmsUtils.log( " Encoding: #{asset.encoding}" )
            enc = "--charset utf-8"
            enc = ""
            cmd = "java"
            params = "-jar \"#{File.join(Folders[:tools], "yuicompressor", "yuicompressor-2.4.7.jar")}\"  #{enc} --type #{ext.gsub(".","")} \"#{asset}\" -o \"#{asset}\""
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

    def Scms.deploy(pub, config)
        yamlpath=File.join(config, "_s3config.yml")
        if File.exists?(yamlpath) 
            S3Deploy.sync(pub, config)
        else
            raise "The following file doesn't exist #{yamlpath}"
        end
    end

    def Scms.Upgrade()
        File.rename("config.yml", "_config.yml") if File.exists? File.join($website, "config.yml")
        File.rename("s3config.yml", "_s3config.yml") if File.exists? File.join($website, "s3config.yml")
    end
end
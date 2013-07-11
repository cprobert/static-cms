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
    
    def Scms.build(website, pub, config, mode)
        @website = website
        @mode = mode
        #ScmsUtils.log("Mode: #{mode}")
        
        ScmsUtils.log("Website #{@website}")
        Scms.sassall(File.join(@website))
        
        yamlpath=File.join(config, "_config.yml")
        @settings = ScmsUtils.getsettings(yamlpath)
        if @settings           
            #Bootstrap here
            if @settings["bootstrap"] != nil
                bootstrap = File.join(@website, @settings["bootstrap"])
                #ScmsUtils.log("Bootstrap is: #{@settings["bootstrap"]}")
                if File.exists?(bootstrap)
                    begin
                        require_relative bootstrap
                    rescue Exception=>e
                        ScmsUtils.errLog( e )
                    end
                else
                    ScmsUtils.log("Bootstrap does not exist #{bootstrap}")
                end
            end 
            
            bundles = Scms.bundle(@settings["bundles"])
            Scms.parsepages(bundles)
        else
            ScmsUtils.errLog("Config is empty")
        end

        ScmsUtils.log("Built website:")
        ScmsUtils.log(ScmsUtils.uriEncode("file:///#{@website}"))
    end

    def Scms.parsepages(bundles)
        # build views from templates
        @template = @settings["template"] 
        
        if @settings["pages"] != nil
            # Build navigation
            navigation = Array.new
            @settings["pages"].each do |pagedata|
                if pagedata != nil
                    pagedata.each do |pageoptions|
                        pagename =  pageoptions[0]
                        pageconfig = pageoptions[1]
                        pageurl = pageconfig["generate"]
                        pageurl = pageconfig["url"] unless pageconfig["url"] == nil
                        navtext = pageconfig["navigation"]
                        navmeta = pageconfig["navigation_meta"]
                        navigation.push({"text" => navtext, "url" => pageurl, "pagename" => pagename, "meta" => navmeta}) unless navtext == nil
                    end
                end
            end

            ScmsUtils.log("Compiling Pages:")
            @settings["pages"].each do |pagedata|
                if pagedata != nil
                    pagedata.each do |pageoptions|
                        pagename =  pageoptions[0]
                        pageconfig = pageoptions[1]
                        pageurl = pageconfig["generate"]
                        title = pagename
                        title = pageconfig["title"] unless pageconfig["title"] == nil
                        description = pageconfig["description"]
                        keywords = pageconfig["keywords"]

                        skin = @template
                        skin = pageconfig["template"] unless pageconfig["template"] == nil
                        
                        resource = Hash.new
                        if pageconfig["resource"] != nil
                            resourcepath = File.join(@website, pageconfig["resource"])
                            if File.exists?(resourcepath)
                                #ScmsUtils.log( "_Resource found: #{pageconfig["resource"]}_" )
                                resource = YAML.load_file(resourcepath)
                            else
                                ScmsUtils.errLog( "Resource not found: #{resourcepath}" )
                            end
                        end
                        
                        hasHandler = false
                        if pageconfig["handler"] != nil
                            handlerpath = File.join(@website, pageconfig["handler"])
                            if File.exists?(handlerpath)
                                #ScmsUtils.log( "Handler found: #{pageconfig["handler"]}" )
                                require handlerpath
                                funDefined = defined? Handler.render
                                if funDefined != nil
                                    hasHandler = true
                                else
                                    ScmsUtils.errLog( "Handler doesnt have a render method" )
                                end
                            else
                                ScmsUtils.errLog( "**Handler not found: #{handlerpath}**" )
                            end
                        end
                        
                        views = Hash.new
                        if pageconfig["views"] != nil
                            pageconfig["views"].each do |view| 
                                views[view[0]] = ""
                                viewpath = File.join(@website, view[1])
                                if File.exists?(viewpath)
                                    htmlsnipet = File.read(viewpath)
                                    if !htmlsnipet.empty?
                                        viewmodel = Hash.new
                                        viewmodel = { 
                                            :page => pagedata, 
                                            :sitedir => @website, 
                                            :resource => resource 
                                        }

                                        if hasHandler
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
                                            views[view[0]] = "<div class='cms' data-view='#{view[1]}' data-page='#{pagedata}'>#{Scms.parsetemplate(viewSnippet, viewmodel)}</div>"
                                        else
                                            views[view[0]] = Scms.parsetemplate(viewSnippet, viewmodel)
                                        end
                                    else
                                        ScmsUtils.writelog("Empty file: #{viewpath}")
                                    end
                                else
                                    ScmsUtils.errLog("View not found: #{view[0]} - #{view[1]} [#{viewpath}]")
                                    ScmsUtils.writelog("View not found: #{view[0]} - #{view[1]} [#{viewpath}]")
                                end
                                #ScmsUtils.log( "view = #{view[0]} - #{view[1]}" )
                            end
                        end

                        monkeyhook = "";
                        monkeyhook = "<script src='scripts/air-monkey-hook.js'></script>" if @mode == "cms"
                        
                        pagemodel = Hash.new
                        pagemodel = { 
                            :name => pagename,
                            :title => title,
                            :description => description,
                            :keywords => keywords,
                            :url => pageurl,
                            :views => views, 
                            :resource => resource, 
                            :config => pageconfig, 
                            :bundles => bundles,
                            :navigation => navigation,
                            :data => pagedata,
                            :rootdir => @website, 
                            :monkeyhook => monkeyhook
                        }
                        
                        erb = File.join(@website, skin)
                        out = File.join(@website, File.join(pageconfig["generate"].sub('~/',''))) unless pageconfig["generate"] == nil
                        
                        ScmsUtils.successLog("#{pageurl}")
                        ScmsUtils.errLog("Template doesn't exist: #{erb}") unless File.exists?(erb)
                        if File.exists?(erb) && out != nil
                            pubsubdir = File.dirname(out)
                            Dir.mkdir(pubsubdir, 755) unless File::directory?(pubsubdir)
                            html = Scms.parsetemplate(File.read(erb), pagemodel)

                            html = html.gsub('~/', ScmsUtils.uriEncode("file:///#{@website}/")) if @mode == "cms"
                            websiteroot = ''
                            websiteroot = @settings["url"] unless @settings["url"] == nil

                            html = html.gsub('~/', websiteroot)

                            File.open(out, 'w') {|f| f.write(html) }
                        end
                    end
                end
                #ScmsUtils.log( out )
            end
        end
    end

    def Scms.parsetemplate(template, hash)
        page = OpenStruct.new(hash)
        result = ""
        
        begin 
            result = ERB.new(template).result(page.instance_eval { binding })
        rescue Exception => e  
                    ScmsUtils.errLog("Critical Error: Could not parse template")
                    ScmsUtils.log( "(if your using resources make sure their not empty)" )
                    ScmsUtils.errLog( e.message )
        end
        
        return result
    end

    def Scms.bundle(bundleConfig)
        bundles = Hash.new
        if bundleConfig != nil
            ScmsUtils.log("Bundeling:")
            bundleConfig.each do |bundle|
                #ScmsUtils.log( "bundle (#{bundle.class}) = #{bundle}" )
                bundle.each do |option|
                    name = option[0]
                    bundleName = File.join(option[1]["generate"])
                    bundles[name] = bundleName
                    ScmsUtils.successLog("#{bundleName}")

                    content = ""
                    assetList = ""
                    files = option[1]["files"]
                    files.each do |asset|
                        assetList += "\t#{asset}\n" 
                        assetname = File.join(@website, asset)
                        if File::exists?(assetname)
                            content = content + "\n" + File.read(assetname)
                        else
                            ScmsUtils.errLog( "Error: No such file #{assetname}" )
                        end
                    end
                    ScmsUtils.log("#{assetList}")
                    
                    bundleDir = File.dirname(bundleName)
                    Dir.mkdir(bundleDir, 755) unless File::directory?(bundleDir)
                    File.open(bundleName, 'w') {|f| f.write(content) }
                    if File.extname(bundleName) == ".js"
                        puts "Minifing: #{bundleName}"
                        Scms.packr(bundleName) unless /(-min)|(\.min)/.match(bundleName)
                    end
                end
            end
        end
        return bundles
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

    def Scms.deploy(website, config)
        yamlpath=File.join(config, "_s3config.yml")
        if File.exists?(yamlpath) 
            S3Deploy.sync(website, config)
        else
            raise "The following file doesn't exist #{yamlpath}"
        end
    end

    def Scms.copywebsite(website, pub)
        if pub != nil
            ScmsUtils.log("Compiling to: #{pub}")
            FileUtils.mkdir pub unless Dir.exists? pub
            source = File.join(website)
            Dir.chdir(source) do          
                Dir.glob("**/*").reject{|f| f['.svn']}.each do |oldfile|
                  newfile = File.join(@target, oldfile.sub(source, ''))
                  #puts newfile
                  File.file?(oldfile) ? FileUtils.copy(oldfile, newfile) : FileUtils.mkdir(newfile) unless File.exist? newfile
                end
            end
            ScmsUtils.log(ScmsUtils.uriEncode("file:///#{pub}"))
        end
    end

    def Scms.upgrade(website)
        File.rename("config.yml", "_config.yml") if File.exists? File.join(website, "config.yml")
        File.rename("s3config.yml", "_s3config.yml") if File.exists? File.join(website, "s3config.yml")
    end
end
require "scms/version"

module Scms
    require 'scms/scms-helpers.rb'
    require 'scms/scms-utils.rb'
    require 'scms/scms-xmlhandler.rb'
    require 'scms/s3deploy.rb'

    require 'erb'
    require 'ostruct' 
    require 'yaml'
    require 'sass'
    require 'packr'
    require 'maruku'
    
    include YAML
    
    def Scms.getsettings(configdir)
        yamlpath=File.join(configdir, "_config.yml")
        settings = ScmsUtils.readyaml(yamlpath)
        if settings           
            return settings
        else
            ScmsUtils.errLog("Config is empty")
        end
    end

    def Scms.build(website, settings, mode = "pub")
        @mode = mode
        #ScmsUtils.log("Mode: #{mode}")
        
        ScmsUtils.boldlog("Compiling #{website}")
        
        if settings           
            #Bootstrap here
            if settings["bootstrap"] != nil
                bootstrap = File.join(website, settings["bootstrap"])
                #ScmsUtils.log("Bootstrap is: #{settings["bootstrap"]}")
                if File.exists?(bootstrap)
                    begin
                        require_relative bootstrap
                    rescue Exception=>e
                        ScmsUtils.errLog(e.message)
                        ScmsUtils.log(e.backtrace.inspect)
                    end
                else
                    ScmsUtils.errLog("Bootstrap does not exist #{settings["bootstrap"]}")
                    ScmsUtils.writelog("::Bootstrap does not exist #{settings["bootstrap"]}", website)
                    ScmsUtils.writelog("type NUL > #{bootstrap}", website)
                end
            end 
            Scms.parsepages(settings, website)
        else
            ScmsUtils.errLog("Config is empty")
        end

        ScmsUtils.boldlog("Built website:")
        ScmsUtils.log(ScmsUtils.uriEncode("file:///#{website}"))
    end

    def Scms.parsepages(settings, website)
        # build views from templates
        
        if settings["pages"] != nil

            # Build bundle model
            bundlemodel = Scms.bundlemodel(settings)
            # Build navigation model
            navmodel = Scms.navmodel(settings)
            #puts "navmodel: #{navmodel}"

            ScmsUtils.log("Compiling Pages:")
            settings["pages"].each do |pagedata|
                #puts "pagedata: #{pagedata}"
                if pagedata != nil
                    pagedata.each do |pageoptions|
                        pagename =  pageoptions[0]
                        pageconfig = pageoptions[1]
                        pageurl = pageconfig["generate"]
                        title = pagename
                        title = pageconfig["title"] unless pageconfig["title"] == nil
                        description = ""
                        description = pageconfig["description"] if pageconfig["description"] != nil
                        keywords = ""
                        keywords = pageconfig["keywords"] if pageconfig["keywords"] != nil
                        skin = settings["template"]
                        skin = pageconfig["template"] unless pageconfig["template"] == nil
                        
                        resource = Hash.new
                        if pageconfig["resource"] != nil
                            resourcepath = File.join(website, pageconfig["resource"])
                            if File.exists?(resourcepath)
                                #ScmsUtils.log( "_Resource found: #{pageconfig["resource"]}_" )
                                begin
                                    resource = YAML.load_file(resourcepath)
                                rescue Exception=>e
                                    ScmsUtils.errLog(e.message)
                                    ScmsUtils.log(e.backtrace.inspect)
                                end
                            else
                                ScmsUtils.errLog("Resource not found: #{pageconfig["resource"]}")
                                ScmsUtils.writelog("::Resource not found #{pageconfig["resource"]}", website)
                                ScmsUtils.writelog("type NUL > #{resourcepath}", website)
                            end
                        end
                        
                        hasHandler = false
                        if pageconfig["handler"] != nil
                            handlerpath = File.join(website, pageconfig["handler"])
                            if File.exists?(handlerpath)
                                ScmsUtils.log( "Handler found: #{pageconfig["handler"]}" )
                                hasHandler = true
                                begin
                                     require handlerpath
                                #     #hasHandler = ScmsHandler.instance_methods(false).include? :render
                                #     hasHandler = ScmsHandler.method_defined?(:render)
                                #     puts "has render method: #{hasHandler}"
                                #     if !hasHandler
                                #         ScmsUtils.errLog( "Handler doesnt have a render method" )
                                #     end
                                rescue Exception => e 
                                    ScmsUtils.errLog( "Problem running: ScmsHandler: #{e.message}" )
                                end
                            else
                                ScmsUtils.errLog("Handler not found: #{pageconfig["handler"]}")
                                ScmsUtils.writelog("::Handler not found #{pageconfig["handler"]}", website)
                                ScmsUtils.writelog("type NUL > #{handlerpath}", website)
                            end
                        end
                        
                        views = Hash.new
                        if pageconfig["views"] != nil
                            pageconfig["views"].each do |view| 
                                views[view[0]] = ""
                                viewparts = view[1].split("?") # This allows views to have a query string in the config
                                viewname = viewparts[0]
                                viewqs = viewparts[1]

                                #puts "viewname: #{viewname}, viewqs: #{viewqs}"

                                viewpath = File.join(website, viewname)
                                

                                if File.exists?(viewpath)
                                    begin
                                        htmlsnipet = File.read(viewpath)
                                    rescue Exception=>e
                                        ScmsUtils.errLog(e.message)
                                        ScmsUtils.log(e.backtrace.inspect)
                                    end
                                    
                                    if htmlsnipet.empty?
                                        ScmsUtils.log("Empty view: #{view[1]}")
                                    end

                                    model = Hash.new
                                    model = Hash[viewqs.split('&').map{ |q| q.split('=') }] if viewqs != nil

                                    viewmodel = Hash.new
                                    viewmodel = { 
                                        :name => pagename,
                                        :title => title,
                                        :url => pageurl,
                                        :data => pagedata,
                                        :rootdir => website, 
                                        :resource => resource,
                                        :view => {
                                            :name => viewname,
                                            :model => model
                                        }
                                    }

                                    if hasHandler
                                        ScmsUtils.log("Rendering with handler")
                                        begin
                                            viewSnippet = ScmsHandler.render(viewpath)
                                        rescue Exception=>e
                                            ScmsUtils.errLog(e.message)
                                            ScmsUtils.log(e.backtrace.inspect)
                                        end
                                        
                                    else
                                        #todo: why not use htmlsnipet
                                        snnipetCode = File.read(viewpath)
                                        
                                        case File.extname(view[1])
                                        when ".xml"
                                            viewSnippet = ScmsXmlHandler.transform(snnipetCode)
                                        when ".md"
                                            begin  
                                                snnipetCode = snnipetCode.encode('UTF-8', :invalid => :replace, :undef => :replace)
                                                doc = Maruku.new(snnipetCode)
                                                viewSnippet = doc.to_html
                                            rescue Exception => e  
                                                viewSnippet = snnipetCode
                                                ScmsUtils.errLog(e.message)
                                                ScmsUtils.log(e.backtrace.inspect)
                                            end
                                        else
                                          viewSnippet = snnipetCode
                                        end
                                    end
                                    
                                    if @mode == "cms"
                                        views[view[0]] = "<div class='cms' data-view='#{view[1]}' data-page='#{pageurl}'>#{Scms.parsetemplate(viewSnippet, viewmodel)}</div>"
                                    else
                                        views[view[0]] = Scms.parsetemplate(viewSnippet, viewmodel)
                                    end
                                else
                                    ScmsUtils.errLog("View not found: #{view[0]} - #{view[1]} [#{viewpath}]")
                                    ScmsUtils.writelog("::View not found: #{view[0]} - #{view[1]} [#{viewpath}]", website)
                                    ScmsUtils.writelog("type NUL > #{viewpath}", website)
                                end
                                #ScmsUtils.log( "view = #{view[0]} - #{view[1]}" )
                            end
                        end

                        monkeyhook = "";
                        monkeyhook = "<script src='scripts/air-monkey-hook.js'></script>" if @mode == "cms"

                        livereload = ""
                        if @mode != "deploy"
                            livereload = "<script>document.write('<script src=\"http://' + (location.host || 'localhost').split(':')[0] + ':35729/livereload.js?snipver=1\"></' + 'script>')</script>" if @mode != "cms"
                        end
                        
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
                            :bundles => bundlemodel,
                            :navigation => navmodel,
                            :data => pagedata,
                            :rootdir => website, 
                            :monkeyhook => monkeyhook,
                            :livereload => livereload
                        }

                        break if pageconfig["generate"] == nil

                        erb = File.join(website, skin)
                        out = File.join(website, File.join(pageconfig["generate"].sub('~/',''))) 
                        
                        #ScmsUtils.log("Generating: #{pageurl} with #{skin}")

                        if File.exists?(erb)
                            pubsubdir = File.dirname(out)
                            Dir.mkdir(pubsubdir, 755) unless File::directory?(pubsubdir)

                            erbtemplate = File.read(erb)

                            #puts "pagemodel: #{pagemodel}"
                            #html = ""
                            html = Scms.parsetemplate(erbtemplate, pagemodel)

                            html = html.gsub('~/', ScmsUtils.uriEncode("file:///#{website}/")) if @mode == "cms"
                            websiteroot = '/'
                            websiteroot = settings["url"] unless settings["rooturl"] == nil

                            html = html.gsub('~/', websiteroot)
                            begin
                                File.open(out, 'w') {|f| f.write(html) }
                            rescue Exception=>e
                                ScmsUtils.errLog(e.message)
                                ScmsUtils.log(e.backtrace.inspect)
                            end
                        else
                            ScmsUtils.errLog("Template doesn't exist: #{skin}")
                            ScmsUtils.writelog("::Template doesn't exist #{skin}", website)
                            ScmsUtils.writelog("type NUL > #{erb}", website)
                        end

                        ScmsUtils.successLog("Generated: #{pageurl}")
                    end
                end
                #ScmsUtils.log( out )
            end
        end
    end

    def Scms.parsetemplate(template, hash = Hash.new)
        result = ""
        if template != nil
            begin 
                if hash.class == OpenStruct 
                    page = hash 
                else
                    page = OpenStruct.new(hash)
                end  

                erb = ERB.new(template)
                result = erb.result(page.instance_eval { binding })
            rescue StandardError => e
                ScmsUtils.errLog("Critical Error: Could not parse template")
                #ScmsUtils.errLog(e.message)
                #puts e.inspect

                result = "Invalid Keys in Template\n\n"
                result += "Valid Keys are:\n"
                hash.each do |key, value|
                    result += "- page.#{key}\n"
                    puts "nil value foy key: #{key}" if value == nil
                    singleton_class.send(:define_method, key) { value }
                end
                
                result += "\n\n"
                result += template
            rescue Exception => e  
                puts "Problem with template - check property exists"
            end
        else
            ScmsUtils.log("Error: Can not parse template.  Template is empty")
        end
        
        return result
    end

    def Scms.bundlemodel(settings)
        puts "Bundeling Assets"
        bundlemodel = Hash.new
        bundleConfig = settings["bundles"]
        if bundleConfig != nil
            bundleConfig.each do |bundle|
                #ScmsUtils.log( "bundle (#{bundle.class}) = #{bundle}" )
                bundle.each do |option|
                    name = option[0]
                    bundleName = File.join(option[1]["generate"])
                    bundlemodel[name] = bundleName
                end
            end
        end
        return bundlemodel
    end

    def Scms.navmodel(settings)
        navmodel = Array.new
        settings["pages"].each do |pagedata|
            if pagedata != nil
                pagedata.each do |pageoptions|
                    pagename =  pageoptions[0]
                    pageconfig = pageoptions[1]
                    pageurl = "about:blank"
                    pageurl = pageconfig["generate"]
                    pageurl = pageconfig["url"] unless pageconfig["url"] == nil
                    navtext = pageconfig["navigation"]
                    navmeta = pageconfig["navigation_meta"]
                    navmodel.push({"text" => navtext, "url" => pageurl, "pagename" => pagename, "meta" => navmeta}) unless navtext == nil
                end
            end
        end
        return navmodel
    end  

    def Scms.bundle(settings, website)
        bundleConfig = settings["bundles"]
        if bundleConfig != nil
            
            bundleConfig.each do |bundle|
                #ScmsUtils.log( "bundle (#{bundle.class}) = #{bundle}" )
                bundle.each do |option|
                    name = option[0]
                    bundleName = File.join(option[1]["generate"])
                    ScmsUtils.boldlog("Bundeling:")

                    content = ""
                    assetList = ""
                    files = option[1]["files"]
                    if files != nil
                        files.each do |asset|
                            assetList += " - #{asset}\n" 
                            assetdir = File.join(website, asset)
                            if File::exists?(assetdir)
                                #try catch for permisions
                                begin
                                    content = content + "\n" + File.read(assetdir)
                                rescue Exception=>e
                                    ScmsUtils.errLog(e.message)
                                    ScmsUtils.log(e.backtrace.inspect)
                                end
                            else
                                ScmsUtils.errLog("Asset file doesn't exists: #{asset}")
                                ScmsUtils.writelog("::Asset file doesn't exists: #{asset}", website)
                                ScmsUtils.writelog("type NUL > #{assetdir}", website)
                            end
                        end
                        ScmsUtils.log("#{assetList}")
                        
                        bundleFullPath = File.join(website, bundleName)
                        bundleDir = File.dirname(File.join(website, bundleName))
                        begin
                            Dir.mkdir(bundleDir, 755) unless File::directory?(bundleDir)
                            File.open(bundleFullPath, 'w') {|f| f.write(content) }
                            ScmsUtils.successLog("Created: #{bundleName}")
                        rescue Exception=>e
                            ScmsUtils.errLog("Error creating bundle: #{bundleName}")
                            ScmsUtils.errLog(e.message)
                            ScmsUtils.log(e.backtrace.inspect)
                        end
                        if File.extname(bundleName) == ".js"
                            puts "Minifing: #{bundleName}"
                            Scms.packr(bundleFullPath) unless /(-min)|(\.min)/.match(bundleName)
                        end
                    else
                        ScmsUtils.errLog("No files in bundle"); 
                    end
                end
            end
        end
    end

    def Scms.sassall(website)
        ScmsUtils.log("Minimising Sass Files (.scss)")
        Dir.chdir(website) do
            Dir.glob("**/*.{scss}").each do |asset|
                Scms.sass(asset, website)
            end
        end
    end

    def Scms.sass(asset, website)
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
                ScmsUtils.log( "CSS minified (sassed): #{css_file}" )
            rescue Exception => e  
                ScmsUtils.errLog("Error processing: #{asset}")
                ScmsUtils.errLog(e.message)
            end
        else
            ScmsUtils.errLog("Sass file doesn't exists: #{asset}")
            ScmsUtils.writelog("::Sass file doesn't exist #{asset}", website)
            ScmsUtils.writelog("type NUL > #{asset}", website)
        end
    end
    
    def Scms.packr(asset)
        if File.exists?(asset)
            begin
                code = File.read(asset)
                compressed = Packr.pack(code)
                File.open(asset, 'w') { |f| f.write(compressed) }
                ScmsUtils.log("Minified #{File.basename(asset)}")
            rescue Exception => e  
                ScmsUtils.errLog("Error processing: #{asset}")
                ScmsUtils.errLog(e.message)
            end
        else
            ScmsUtils.errLog("Can't minify asset because file doesn't exist: #{asset}")
        end
    end

    def Scms.copywebsite(website, pub)
        if pub.to_s.strip.length != 0
            FileUtils.mkdir pub unless Dir.exists? pub
            source = File.join(website)
            Dir.chdir(source) do          
                Dir.glob("**/*").reject{|f| f['.svn']}.each do |oldfile|
                  newfile = File.join(pub, oldfile.sub(source, ''))
                  #puts newfile
                  File.file?(oldfile) ? FileUtils.copy(oldfile, newfile) : FileUtils.mkdir(newfile) unless File.exist? newfile
                end
            end
            ScmsUtils.log("Output to: #{ScmsUtils.uriEncode("file:///#{pub}")}")
        end
    end
end
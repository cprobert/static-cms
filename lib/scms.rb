module Scms
    require "scms/version"
    require 'scms/scms-pageoptions.rb'
    require 'scms/scms-helpers.rb'
    require 'scms/scms-utils.rb'
    require 'scms/scms-xmlhandler.rb'
    require 'scms/s3deploy.rb'

    require 'fileutils'
    require 'pathname'
    require 'erb'
    require 'ostruct' 
    require 'yaml'
    require 'sass'
    require 'packr'
    require 'maruku'
    
    include YAML
    
    def Scms.getSettings(configdir)
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
            Scms.parsePages(settings, website)
        else
            ScmsUtils.errLog("Config is empty")
        end

        ScmsUtils.boldlog("Built website:")
        ScmsUtils.log(ScmsUtils.uriEncode("file:///#{website}"))
    end

    def Scms.parsePages(settings, website)
        # build pages defined in config file
        Scms.parseSettingsPages(settings, website)
        # build pages pased on _pages folder
        Scms.parsePagesDir(settings, website)
    end

    def Scms.parseSettingsPages(settings, website)
        if settings["pages"] != nil

            ScmsUtils.log("Compiling Pages:")
            settings["pages"].each do |pagedata|
                #puts "pagedata: #{pagedata}"
                if pagedata != nil
                    pagedata.each do |pageOptions|
                        pagename =  pageOptions[0]
                        pageconfig = pageOptions[1]

                        pageOptions = PageOptions.new(pagename, website, pageconfig, settings)
                        
                        views = Hash.new
                        if pageconfig["views"] != nil
                            pageconfig["views"].each do |view| 
                                viewname = view[0]
                                viewparts = view[1].split("?") # This allows views to have a query string in the config
                                viewpath = viewparts[0]
                                viewqs = viewparts[1]

                                viewModel = Hash.new
                                viewModel = Hash[viewqs.split('&').map{ |q| q.split('=') }] if viewqs != nil
                                views[viewname] = Scms.parseView(viewname, viewpath, website, pageOptions, viewModel)
                            end
                        end

                        # Dont save a page if no views have been defined (so the config han have pages for nav building)
                        break if views.length < 1

                        Scms.save(settings, website, pageOptions, views)
                    end
                end
                #ScmsUtils.log( out )
            end
        end
    end

    def Scms.parsePagesDir(settings, website)
        pagesFolder = File.join(website, "_pages")
        Dir.glob("#{pagesFolder}/**/*/").each do |pageFolder|
            pagename = File.basename(pageFolder, ".*")
            #puts "pagename: #{pagename}"

            pageconfig = nil
            pageconfig = Scms.getSettings(pageFolder) if File.exists?(File.join(pageFolder, "_config.yml"))
            pageOptions = PageOptions.new(pagename, website, pageconfig, settings)

            views = Hash.new
            Dir.glob(File.join(pageFolder, "*")).reject { |f| f =~ /\.yml$/ || File.directory?(f) }.each do |view|
                viewname = File.basename(view, ".*")
                viewpath = Pathname.new(view).relative_path_from(Pathname.new(website)).to_s
                views[viewname] = Scms.parseView(viewname, viewpath, website, pageOptions)
            end
            Scms.save(settings, website, pageOptions, views)
        end
    end

    def Scms.parseView(viewname, viewpath, website, pageOptions, viewModel = nil)
        #puts "parsing view: #{viewname}"

        viewhtml = ""
        viewfullpath = File.join(website, viewpath)

        if File.exists?(viewfullpath)
            begin
                htmlsnipet = File.read(viewfullpath)
            rescue Exception=>e
                ScmsUtils.errLog(e.message)
                ScmsUtils.log(e.backtrace.inspect)
            end
            
            if htmlsnipet.empty?
                ScmsUtils.log("Empty view: #{viewpath}")
            end

            hasHandler = false
            if pageOptions.handler != nil
                handlerpath = File.join(website, pageOptions.handler)
                if File.exists?(handlerpath)
                    ScmsUtils.log( "Handler found: #{pageOptions.handler}" )
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
                    ScmsUtils.errLog("Handler not found: #{pageOptions.handler}")
                    ScmsUtils.writelog("::Handler not found #{pageOptions.handler}", website)
                    ScmsUtils.writelog("type NUL > #{handlerpath}", website)
                end
            end

            if hasHandler
                ScmsUtils.log("Rendering with handler")
                begin
                    viewSnippet = ScmsHandler.render(viewpath)
                rescue Exception=>e
                    ScmsUtils.errLog(e.message)
                    ScmsUtils.log(e.backtrace.inspect)
                end
            else
                case File.extname(viewpath)
                when ".xml"
                    viewSnippet = ScmsXmlHandler.transform(htmlsnipet)
                when ".md"
                    begin  
                        htmlsnipet = htmlsnipet.encode('UTF-8', :invalid => :replace, :undef => :replace)
                        doc = Maruku.new(htmlsnipet)
                        viewSnippet = doc.to_html
                    rescue Exception => e  
                        viewSnippet = htmlsnipet
                        ScmsUtils.errLog(e.message)
                        ScmsUtils.log(e.backtrace.inspect)
                    end
                else
                  viewSnippet = htmlsnipet
                end
            end

            viewmodel = Hash.new
            viewmodel = { 
                :name => pageOptions.name,
                :title => pageOptions.title,
                :url => pageOptions.url,
                :resource => pageOptions.resource,
                :rootdir => website, 
                :view => {
                    :name => viewname,
                    :path => viewfullpath,
                    :model => viewModel
                }
            }
            
            if @mode == "cms"
                viewhtml = "<div class='cms' data-view='#{pageOptions.name}' data-page='#{pageOptions.url}'>#{Scms.render(viewSnippet, viewmodel)}</div>"
            else
                viewhtml = Scms.render(viewSnippet, viewmodel)
            end
        else
            ScmsUtils.errLog("View not found: #{viewname} [#{viewpath}]")
            ScmsUtils.writelog("::View not found: #{viewname} [#{viewpath}]", website)
            ScmsUtils.writelog("type NUL > #{viewpath}", website)
        end

        return viewhtml
    end

    def Scms.parsetemplate(template, hash = Hash.new)
        return Scms.render(template, hash)
    end

    def Scms.render(template, hash = Hash.new)
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
                
                ScmsUtils.errLog(e.message)
                puts e.inspect
                puts "page: #{page}"

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

    def Scms.save(settings, website, pageOptions, views)

        fileName = File.join(website, File.join(pageOptions.url.sub('~/',''))) 
        erb = File.join(website, pageOptions.template)
        #ScmsUtils.log("Generating: #{fileName} with #{pageOptions.template}")

        if File.exists?(erb)

            # Build bundle model
            bundleModel = Scms.bundleModel(settings)
            # Build navigation model
            navModel = Scms.navModel(settings)
            #puts "navModel: #{navModel}"

            monkeyhook = "";
            monkeyhook = "<script src='scripts/air-monkey-hook.js'></script>" if @mode == "cms"

            livereload = ""
            if @mode != "deploy"
                livereload = "<script async='true' defer='true'>document.write('<script src=\"http://' + (location.host || 'localhost').split(':')[0] + ':35729/livereload.js?snipver=1\"></' + 'script>')</script>" if @mode != "cms"
            end
            
            pagemodel = Hash.new
            pagemodel = { 
                :name => pageOptions.name,
                :title => pageOptions.title,
                :description => pageOptions.description,
                :keywords => pageOptions.keywords,
                :url => pageOptions.url,
                :resource => pageOptions.resource, 
                :bundles => bundleModel,
                :navigation => navModel,
                :views => views, 
                :rootdir => website, 
                :monkeyhook => monkeyhook,
                :livereload => livereload
            }

            #puts "pagemodel:"
            #puts pagemodel

            pubsubdir = File.dirname(fileName)
            Dir.mkdir(pubsubdir, 755) unless File::directory?(pubsubdir)

            erbtemplate = File.read(erb)

            #puts "pagemodel: #{pagemodel}"
            #html = ""
            html = Scms.render(erbtemplate, pagemodel)

            html = html.gsub('~/', ScmsUtils.uriEncode("file:///#{website}/")) if @mode == "cms"
            websiteroot = '/'
            websiteroot = settings["url"] unless settings["rooturl"] == nil

            html = html.gsub('~/', websiteroot)
            begin
                File.open(fileName, 'w') {|f| f.write(html) }
                ScmsUtils.successLog("Generated: #{pageOptions.url}")
            rescue Exception=>e
                ScmsUtils.errLog(e.message)
                ScmsUtils.log(e.backtrace.inspect)
            end
        else
            ScmsUtils.errLog("Template doesn't exist: #{pageOptions.template}")
            ScmsUtils.writelog("::Template doesn't exist #{pageOptions.template}", website)
            ScmsUtils.writelog("type NUL > #{erb}", website)
        end
    end

    def Scms.bundleModel(settings)
        bundleModel = Hash.new
        bundleConfig = settings["bundles"]
        if bundleConfig != nil
            bundleConfig.each do |bundle|
                #ScmsUtils.log( "bundle (#{bundle.class}) = #{bundle}" )
                bundle.each do |option|
                    name = option[0]
                    bundleName = File.join(option[1]["generate"])
                    bundleModel[name] = bundleName
                end
            end
        end
        return bundleModel
    end

    def Scms.navModel(settings)
        navModel = Array.new
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
                    navModel.push({"text" => navtext, "url" => pageurl, "pagename" => pagename, "meta" => navmeta}) unless navtext == nil
                end
            end
        end
        return navModel
    end  

    def Scms.bundle(settings, website)
        bundleConfig = settings["bundles"]
        if bundleConfig != nil
            
            bundleConfig.each do |bundle|
                #ScmsUtils.log( "bundle (#{bundle.class}) = #{bundle}" )
                bundle.each do |option|
                    #name = option[0]
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

    def Scms.copyWebsite(website, pub)
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
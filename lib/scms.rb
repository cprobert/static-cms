module Scms
    require "scms/version"
    require 'scms/scms-utils.rb'
    require 'scms/scms-helpers.rb'
    require 'scms/scms-pageoptions.rb'
    require 'scms/scms-bundler.rb'
    require 'scms/scms-parser.rb'
    require 'scms/scms-xmlhandler.rb'

    require 'fileutils'
    require 'pathname'
    require 'erb'
    require 'ostruct' 
    require 'yaml'
    require 'sass'
    require 'packr'
    require 'maruku'
    
    include YAML
    
    #public
    def Scms.getSettings(configdir)
        yamlpath=File.join(configdir, "_config.yml")
        settings = ScmsUtils.readyaml(yamlpath)
        if settings           
            return settings
        else
            ScmsUtils.errLog("Config is empty")
        end
    end

    #public
    def Scms.build(website, settings, options)
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
            ScmsUtils.log("Generating pages")
            Scms.generatePages(website, settings, options)
        else
            ScmsUtils.errLog("Config is empty")
        end

        ScmsUtils.boldlog("Built website:")
        ScmsUtils.log(ScmsUtils.uriEncode("file:///#{website}"))
    end

    private
    def Scms.generatePages(website, settings, options)
        # build pages pased on _pages folder
        Scms.generatePagesFromFolder(website, settings, options)
        # build pages defined in config file
        Scms.generatePagesFromSettings(website, settings, options)
    end

    private
    def Scms.generatePagesFromFolder(website, settings, options)
        pagesFolder = File.join(website, "_pages")
        Dir.glob("#{pagesFolder}/**/*/").each do |pageFolder|
            pagename = File.basename(pageFolder, ".*")
            pageconfig = nil
            pageConfigPath = File.join(pageFolder, "_config.yml")
            if File.exists?(pageConfigPath)
                pageconfig = Scms.getSettings(pageFolder) 
            else
                begin
                    ScmsUtils.log("Creating page config:")
                    ScmsUtils.log(pageConfigPath)
                    File.open(pageConfigPath, 'w') {|f| f.write("title: "+ pagename) }
                rescue Exception=>e
                    ScmsUtils.errLog(e.message)
                    ScmsUtils.log(e.backtrace.inspect)
                end
            end

            pageOptions = PageOptions.new(pagename, website, pageconfig, settings)
            views = Hash.new {}
            if pageconfig != nil
                views = Scms.getSettingsViews(pageconfig["views"], website, pageOptions, options) if pageconfig["views"] != nil
            else
                # Add config generation here
            end
            
            Dir.glob(File.join(pageFolder, "*")).reject { |f| f =~ /\.yml$/ || File.directory?(f) }.each do |view|
                viewname = File.basename(view, ".*")
                viewpath = Pathname.new(view).relative_path_from(Pathname.new(website)).to_s
                viewmodel = Scms.getViewModel(viewname, viewpath, website, pageOptions, options)
                views[viewname] = Scms.renderView(viewpath, viewmodel)
            end
            Scms.savePage(settings, website, pageOptions, views, options)
        end
    end

    private
    def Scms.generatePagesFromSettings(website, settings, options)
        if settings["pages"] != nil
            ScmsUtils.log("Compiling Pages:")
            settings["pages"].each do |pagedata|
                if pagedata != nil
                    pagedata.each do |pageOptions|
                        pagename =  pageOptions[0]
                        pageconfig = pageOptions[1]

                        pageOptions = PageOptions.new(pagename, website, pageconfig, settings)
                        views = Scms.getSettingsViews(pageconfig["views"], website, pageOptions, options)

                        # Dont save a page if no views have been defined (so the config han have pages for nav building)
                        break if views.length < 1
                        Scms.savePage(settings, website, pageOptions, views, options)
                    end
                end
            end
        end
    end

    private
    def Scms.getSettingsViews(settingsViews, website, pageOptions, options)
        views = Hash.new {}
        if settingsViews != nil
            settingsViews.each do |view| 
                viewname = view[0]
                
                viewparts = view[1].split("?") # This allows views to have a query string in the config
                viewpath = viewparts[0]
                viewqs = viewparts[1]
                viewData = Hash[viewqs.split('&').map{ |q| q.split('=') }] if viewqs != nil

                viewmodel = Scms.getViewModel(viewname, viewpath, website, pageOptions, options, viewData)
                views[viewname] = Scms.renderView(viewpath, viewmodel)
            end
        end
        return views
    end

    private
    def Scms.getViewModel(viewname, viewpath, website, pageOptions, options, viewData = nil)
        #puts "parsing view: #{viewname}"

        viewmodel = Hash.new {}
        viewfullpath = File.join(website, viewpath)

        if File.exists?(viewfullpath)
            viewmodel = { 
                :name => pageOptions.name,
                :title => pageOptions.title,
                :url => pageOptions.url,
                :resource => pageOptions.resource,
                :rootdir => website,
                :mode =>  options[:mode],
                :allowEdit => pageOptions.allowEdit,
                :view => {
                    :name => viewname,
                    :path => viewpath,
                    :data => viewData
                }
            }
        else
            ScmsUtils.errLog("View not found: #{viewname} [#{viewpath}]")
            ScmsUtils.writelog("::View not found: #{viewname} [#{viewpath}]", website)
            ScmsUtils.writelog("type NUL > #{viewpath}", website)
        end

        return viewmodel
    end

    private
    def Scms.savePage(settings, website, pageOptions, views, options)
        fileName = File.join(website, File.join(pageOptions.url.sub('~/',''))) 
        erb = File.join(website, pageOptions.template)
        #ScmsUtils.log("Generating: #{fileName} with #{pageOptions.template}")

        if File.exists?(erb)
            bundleModel = Scms.getBundleModel(website, settings, options)# Build bundle model
            navModel = Scms.getNavModel(website, settings, options)# Build navigation model

            websiteroot = '/'
            websiteroot = settings["rooturl"] if settings["rooturl"] != nil
            websiteroot = ScmsUtils.uriEncode("file:///#{website}/") if options[:mode] == "cms"

            monkeyhook = "";
            monkeyhook = "<script src='~/scripts/air-monkey-hook.js'></script>".gsub("~/", websiteroot) if options[:mode] == "cms"

            livereload = ""
            if options[:watch]
                livereload = "<script async='true' defer='true'>document.write('<script src=\"http://' + (location.host || 'localhost').split(':')[0] + ':35729/livereload.js?snipver=1\"></' + 'script>')</script>" if options[:mode] != "cms"
            end
            
            pagemodel = Hash.new {}
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

            pubsubdir = File.dirname(fileName)
            Dir.mkdir(pubsubdir, 755) unless File::directory?(pubsubdir)

            erbtemplate = File.read(erb)

            parser = ScmsParser.new(erbtemplate, pagemodel)
            html = parser.parse()
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

    private
    def Scms.getNavModel(website, settings, options)
        websiteroot = '/'
        websiteroot = settings["rooturl"] unless settings["rooturl"] == nil
        websiteroot = ScmsUtils.uriEncode("file:///#{website}/") if options[:mode] == "cms"
        #websiteroot = "" if options[:mode] == "cms"

        navModel = Array.new
        if settings["pages"] != nil
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
                        navModel.push({"text" => navtext, "url" => pageurl.gsub("~/", websiteroot), "pagename" => pagename, "meta" => navmeta}) unless navtext == nil
                    end
                end
            end
        end
        if settings["nav"] != nil
            settings["nav"].each do |pagedata|
                if pagedata != nil
                    pagedata.each do |pageoptions|
                        pagename =  pageoptions[0]
                        pageconfig = pageoptions[1]

                        pageurl = "about:blank"
                        pageurl = pageconfig["url"] unless pageconfig["url"] == nil

                        #pageUrlExt = File.extname(pageurl) 
                        #puts "pageUrlExt: #{pageUrlExt}"
                        #puts "No extension" if pageUrlExt == ""
                        if options[:mode] == "cms"
                            pageurl += "index.html"  if pageurl.match(/\/$/)
                        end

                        navtext = pagename
                        navtext = pageconfig["text"]

                        navmeta = pageconfig["meta"]

                        navModel.push({"text" => navtext, "url" => pageurl.gsub("~/", websiteroot), "pagename" => pagename, "meta" => navmeta})
                    end
                end
            end
        end
        return navModel
    end  

    private
    def Scms.getBundleModel(website, settings, options)
        bundleModel = Hash.new {}
        websiteroot = '/'
        websiteroot = settings["rooturl"] unless settings["rooturl"] == nil
        websiteroot = ScmsUtils.uriEncode("file:///#{website}/") if options[:mode] == "cms"
        
        Dir.glob('**/*.bundle').each do|bundle|
            getGeneratedBundleName = ScmsBundler.getGeneratedBundleName(bundle)
            stub = ScmsBundler.toStub(bundle)
            bundleModel[bundle] = getGeneratedBundleName
            bundleModel[stub] = getGeneratedBundleName #Access bundle model without bundle extention
        end 

        bundleConfig = settings["bundles"]
        if bundleConfig != nil
            bundleConfig.each do |bundle|
                #ScmsUtils.log( "bundle (#{bundle.class}) = #{bundle}" )

                bundle.each do |option|
                    name = option[0]
                    config = option[1]

                    bundleName = File.join(config["generate"])
                    bundleModel[name] = bundleName.gsub("~/", websiteroot)
                end
            end
        end
        # puts "Bundle model:"
        # puts bundleModel
        # puts "----------------------------"
        return bundleModel
    end

    private
    def Scms.bundler(bundle = nil)
        if bundle == nil
            ScmsBundler.run()
        else
            ScmsBundler.bundle(bundle)
        end
    end

    #public
    def Scms.bundle(settings, website)
        Scms.bundler()

        if settings != nil
            bundleConfig = settings["bundles"]
            if bundleConfig != nil
                ScmsUtils.boldlog("Bundeling:")

                bundleConfig.each do |bundle|
                    #ScmsUtils.log( "bundle (#{bundle.class}) = #{bundle}" )
                    bundle.each do |option|
                        name = option[0]
                        config = option[1]

                        bundleName = File.join(config["generate"].gsub("~/",""))
                        

                        content = ""
                        assetList = ""
                        files = config["files"]
                        if files != nil
                            files.each do |asset|
                                assetList += " - #{asset}\n" 
                                assetdir = File.join(website, asset)
                                if File::exists?(assetdir)
                                    #try catch for permisions
                                    begin
                                        content = content + "\n\n" + File.read(assetdir)
                                    rescue Exception=>e
                                        ScmsUtils.errLog(e.message)
                                        ScmsUtils.log(e.backtrace.inspect)

                                        ScmsUtils.log("#{assetList}")
                                    end
                                else
                                    ScmsUtils.errLog("Asset file doesn't exists: #{asset}")
                                    ScmsUtils.writelog("::Asset file doesn't exists: #{asset}", website)
                                    ScmsUtils.writelog("type NUL > #{assetdir}", website)
                                end
                            end
                            
                        else
                            ScmsUtils.errLog("No files in bundle"); 
                        end

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
                            #puts "Minifing: #{bundleName}"
                            Scms.packr(bundleFullPath) unless /(-min)|(\.min)/.match(bundleName)
                        end
                    end
                end
            end
        end
    end

    #public
    def Scms.sassall(website)
        ScmsUtils.log("Minimising Sass Files (.scss)")
        Dir.chdir(website) do
            Dir.glob("**/*.{scss}").each do |asset|
                Scms.sass(asset)
            end
        end
    end

    #public
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
                ScmsUtils.log( "CSS minified (sassed): #{css_file}" )
            rescue Exception => e  
                ScmsUtils.errLog("Error processing: #{asset}")
                ScmsUtils.errLog(e.message)
            end
        else
            ScmsUtils.errLog("Sass file doesn't exists: #{asset}")
        end
    end
    
    def Scms.packr(asset)
        #puts "Trying to pack: #{asset}"
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

    #public
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

    #public
    def Scms.getView(viewname, page = OpenStruct.new, ext = "html")
        if page.views != nil
            htmlSnippet = page.views[viewname]
            if htmlSnippet != nil
                return htmlSnippet
            else
                begin
                    viewPath = File.join(page.rootdir, "_pages", page.name, viewname +"."+ ext)
                    ScmsUtils.log("Creating view:")
                    ScmsUtils.log(viewPath)
                    File.open(viewPath, 'w') {|f| f.write("edit me") }
                rescue Exception=>e
                    ScmsUtils.errLog(e.message)
                    ScmsUtils.log(e.backtrace.inspect)
                end
                return ""
            end
        else
            return ""
        end
    end

    #public #legasy
    def Scms.renderView(viewpath, hash = Hash.new)
        return Scms.getSnippet(viewpath, hash)
    end
    #public
    def Scms.getSnippet(viewpath, hash = Hash.new)
        #puts "** Rendering: #{viewpath} **"

        htmlsnipet = ""
        begin
            htmlsnipet = File.read(viewpath)
        rescue Exception=>e
            ScmsUtils.errLog(e.message)
            ScmsUtils.log(e.backtrace.inspect)
        end
        ScmsUtils.log("Empty view: #{viewpath}") if htmlsnipet.empty?

        template = ""

        case File.extname(viewpath)
        when ".xml"
            template = ScmsXmlHandler.transform(htmlsnipet)
        when ".md"
            begin  
                doc = Maruku.new(htmlsnipet)
                template = ScmsUtils.toUTF8(doc.to_html)
            rescue Exception => e  
                template = htmlsnipet
                ScmsUtils.errLog(e.message)
                ScmsUtils.log(e.backtrace.inspect)
            end
        else
            template = ScmsUtils.toUTF8(htmlsnipet)
        end

        parser = ScmsParser.new(template, hash)
        return parser.parse(viewpath)
    end
end
A static website CMS
====================

If you need to build a quick html website but don't want to maintain each page independantly Static-CMS could be for you.
StaticCMS is a static website builder that creates html files from an eruby template.  This facilitates the management of the skin/theme from a single file.
It also has a few nifty features such as JavaScript and CSS bundeling and minimisation
When your happy with your website StaticCMS will also deploy to AmazonS3 setting approperate caching settings.

### Installing 

    gem install scms

### Creating a website 

    scms -a create -w /path/to/folder

(if the -w flag is excluded it assumes current directory)

### Building your website 

    scms -a build -w /path/to/folder
    
(if the -a flag is excluded defult action is 'build')

### Publishing your website 

    scms -a deploy -w /path/to/folder


Further Reading
---------------

 * Homepage: http://cprobert.github.io/Static-CMS/
 * ERB template language: http://www.stuartellis.eu/articles/erb/

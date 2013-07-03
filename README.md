A static website CMS

StaticCMS is website builder that creates html files from an eruby template.  
This facilitates the management of the skin/theme from a single file.

Installing:

gem install scms

Creating a website:

scms -a create -w /path/to/folder

Building your website

scms - build -w /path/to/folder

Publishing your website

scms -a deploy -w /path/to/folder

Editing a Static-CMS website

open /path/to/folder

Step 1:
Edit the config.yml to your website structute

Step 2:
Run the build script this will generate the html files from the views.
The build atrifacts will be found in the pub directory.
Please note you need to pass the website folder as a parameter to the build script

Step 3:
To publish you will need to run the deploy script.
Please note you first need to enter your S3 credentials in the s3config.yml config file (including the bucket name)
You will also need copy your s3 certs to www/s3certs


Information on the directory structure 

'/templates'
Here you will find the template(s) tht's used for the web skin/theme

'/views'
This containd the views that contain the content/html to be inhected into the mater theme

'/public'
Place the other static website assets here. 

Further reading for the template language
http://www.stuartellis.eu/articles/erb/

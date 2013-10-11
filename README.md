A static website CMS
====================

If you need to build a quick html website but don't want to maintain each page independantly Static-CMS could be for you.
StaticCMS is a static website builder that creates html files from an eruby template.  This facilitates the management of the layout/skin/theme from a single file.
It also has a few nifty features such as JavaScript and CSS bundeling and minimisation
When your happy with your website StaticCMS will also deploy to AmazonS3 setting approperate caching settings.

Find it useful? Then let me know: https://twitter.com/c_probert

	gem install scms
	scms --create mynewsite
	cd mynewsite
	scms --serve

Further Reading
---------------

 * Homepage: http://cprobert.github.io/Static-CMS
 * WYSIWYG editor: http://ipassexam.github.io/Air-Monkey/


 * ERB template language: http://www.stuartellis.eu/articles/erb/

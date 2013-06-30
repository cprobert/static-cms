<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:a="http://ns.adobe.com/air/application/3.0">
<xsl:output method="xml" indent="yes"/>
	<xsl:template match="/a:application">
	
<update xmlns="http://ns.adobe.com/air/framework/update/description/2.5">
	<versionNumber><xsl:value-of select="a:versionNumber"/></versionNumber>
	<!--<url>file:///C:/Users/cprobert/Desktop/AirMonkey/Air-Monkey_<xsl:value-of select="a:versionNumber"/>.exe</url>-->
	<url>http://static-cms.googlecode.com/files/Air-Monkey_<xsl:value-of select="a:versionNumber"/>.exe</url>
	<description>
	<![CDATA[
		This is the latest version of Air Monkey
	]]>
	</description>
</update>
		
	</xsl:template>
</xsl:stylesheet>
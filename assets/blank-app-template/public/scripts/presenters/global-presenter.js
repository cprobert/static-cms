$(function(){
	//wire external links
	$("a[href^='http']").click(function(e){
			e.preventDefault();
			href = $(this).attr("href");
			page.openExternalURL(href)
	});
});
/// Author Courtenay Probert
/// Version 1.1.1

$(function() {
	function editMe(cms) {
		var view = $(cms).attr("data-view");
        if(!view)
            alert("View missing");
            
		var page = $(cms).attr("data-page");
        if(!page)
            alert("Page missing");
            
        try{
            if(window.parentSandboxBridge !== undefined)
                window.parentSandboxBridge.editView(view, page);
            else
                alert("No Parent Sandbox Bridge");
        } catch (e) {
            alert(e);
        }
	}

	$("a[href^='http']")
		.attr('target','_blank')
		.click(function(e){
			e.preventDefault();
			href = $(this).attr("href");
			alert("Loading: "+ href);
			window.parentSandboxBridge.openExternalURL(href);
	});

	$(".cms").each(function(i) {
		var $this = $(this);
		$this.addClass("cmsEdit");
		var bgColor = $(this).css("background-color");

		var addTextMsg = "Double click to add text";
		$this
			.bind("dblclick", function(event) {
				event.stopPropagation();
				editMe(this);
			})
			.attr("title", "Double click to edit")
			.mouseover(function() {
				if ($.trim($this.html()) === "")
					$this.html(addTextMsg);
				$(this).css({
						backgroundColor: '#FFFFE0',
						cursor: 'pointer'
				});
			})
			.mouseout(function() {
				if ($.trim($this.html()) === addTextMsg)
					$this.html("");
				$this.css({
					backgroundColor: bgColor
				});
			});
	}).attr("style", "min-height: 25px;");
});
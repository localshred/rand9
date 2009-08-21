function calcHeightWithPadding(e)
{
	paddingTop = parseInt(e.css("paddingTop").replace(/px/, ""));
	paddingBottom = parseInt(e.css("paddingBottom").replace(/px/, ""));
	height = parseInt(e.css("height").replace(/px/, ""));
	return height+paddingTop+paddingBottom;
}

$(document).ready(function(){
	// Logo Hover
	$("h1#logo").hover(function(){ $(this).addClass('logo-hover'); }, function(){ $(this).removeClass('logo-hover'); });
	
	// Logo clicking
	$("h1#logo").click(function(){ location.href = '/'; });
	
	// Tweets
	$("div#tweets").tweetable({ link_to_tweet: true });
	
	// Pulldown panel for about
	$("div#menu li.pulldown a").click(function(){
		panel = $("#panel.about");
		height = calcHeightWithPadding(panel);
		top = parseInt(panel.css("top").replace(/px/, ""));
		mainDuration = 500;
		shortDuration = 120;
		menuDiv = $(this).parent(0).parent(0).parent(0);
		
		if (top < 0)
		{
			// drop it down
			panel
				.css({top: height*-1}) // set the top properly
				.animate({top: 0, paddingTop: 60}, mainDuration) // animate animate to top:0, expand top padding by 20
				.animate({paddingTop: 20}, shortDuration) // expand top padding to norm (40)
				.animate({paddingTop: 40}, shortDuration); // expand top padding to norm (40)
			
			menuDiv
				.addClass("panel-open")
				.addClass("opaque")
				.animate({top: height+20}, mainDuration) // animate to the height of panel+20
				.animate({top: height-20}, shortDuration) // contract top by 40
				.animate({top: height}, shortDuration); // expand top to regular panel height
			
			$(this).html("about &uarr;");
		}
		else
		{
			// bring it back up
			panel
				.animate({paddingTop: 60}, shortDuration)
				.animate({top: height*-1}, mainDuration)
				.animate({paddingTop: 40}, shortDuration);
			menuDiv
				.animate({top: height+20}, shortDuration)
				.animate({top: 0}, mainDuration)
				.removeClass("panel-open")
				.removeClass("opaque");
			$(this).html("about &darr;");
		}
	});
	
	// Post Synopsis click
	$("div.post-synopsis").click(function(e){
		location.href = "/"+($(this).attr("id").replace(/post_/, ""))+".html";
	});
	
	$("div.post-full p img").each(function(){
		$(this).parent(0).parent(0).addClass("article-image");
	});
	
});
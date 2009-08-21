//extend the plugin
(function($){

	//define the new for the plugin ans how to call it	
	$.fn.tweetable = function(options) {
		//set default options  
		var defaults = {
			limit: 5,
			username: 'localshred',
			time: false,
			link_to_tweet: false
		};

		//call in the default otions
		var options = $.extend(defaults, options);
		//act upon the element that is passed into the design    
		return this.each(function(options) {
			var act = $(this);
			var api = "http://twitter.com/statuses/user_timeline/";
			var count= "?count=";
			$.getJSON(api+defaults.username+".json"+count+defaults.limit+"&callback=?", act,
			function(data){
				$(act).html('<ul id="tweet-list"></ul>');
				$.each(data, function(i,item){
					$("ul#tweet-list").append('<li id="tweet-'+i+'"></li>');
					$('li#tweet-'+i+'').append(
						item.text
						.replace(/(\b(https?|ftp|file):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|])/ig, '<a href="$&" target="_blank">$&</a> ' ) // insert regular links
						.replace(/#([a-z0-9_]*?)([^a-z0-9_]|$)/g, '<a href="http://search.twitter.com/search?q=%23$1" title="Search topic #$1 on twitter" target="_blank" class="hash">#$1</a> ') // insert topic hash links
						.replace(/@([a-z0-9_]*?)([^a-z0-9_]|\(|\)|$)/g, '<a href="http://twitter.com/$1" target="_blank">@$1</a> $2') // insert user links
					);
					if (defaults.time == true)
						$('li#tweet-'+i).append(' <span class="created-date">'+item.created_at.substr(0,20)+'</span>');	
					if (defaults.link_to_tweet == true)
						$('li#tweet-'+i).append(' <a href="http://www.twitter.com/'+defaults.username+'/status/'+item.id+'" title="Go to tweet" target="_blank">&raquo;</a>');	
		    }); // end $.each
     	}) // end callback
		}); // end return
	};// end tweetable
})(jQuery);

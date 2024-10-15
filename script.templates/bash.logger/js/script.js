$(window).load(function() {
	var pageHeight = $(document).height();
	var scrollPos = $(document).scrollTop();
	var currentPos = $(document).scrollTop() + $(window).height();

	if (scrollPos == 0 || pageHeight == currentPos) {
		$("html, body").animate({ scrollTop: pageHeight }, 1000);
	}
});

$(document).ready(function() {

/*	setTimeout(function(){
		window.location.reload(1);
	}, 15000);
*/
	var pre = document.getElementsByTagName('pre'),
		pl = pre.length;

	for (var i = 0; i < pl; i++) {
		pre[i].innerHTML = '<span class="line-number"></span>' + pre[i].innerHTML + '<span class="cl"></span>';

		var num = countLines(document.getElementById("code"));
		for (var j = 0; j < num; j++) {
			var line_num = pre[i].getElementsByTagName('span')[0];
			line_num.innerHTML += '<span>' + (j + 1) + '</span>';
		}
	}
});

function countLines(target) {
	var style = window.getComputedStyle(target, null);
	var height = parseInt(style.getPropertyValue("height"));
	var font_size = parseInt(style.getPropertyValue("font-size"));
	var line_height = parseInt(style.getPropertyValue("line-height"));
	var box_sizing = style.getPropertyValue("box-sizing");

	if(isNaN(line_height)) line_height = font_size * 1.2;

	if(box_sizing=='border-box')
	{
		var padding_top = parseInt(style.getPropertyValue("padding-top"));
		var padding_bottom = parseInt(style.getPropertyValue("padding-bottom"));
		var border_top = parseInt(style.getPropertyValue("border-top-width"));
		var border_bottom = parseInt(style.getPropertyValue("border-bottom-width"));
		height = height - padding_top - padding_bottom - border_top - border_bottom
	}

	target.style.paddingLeft = '0';

	var lines = Math.ceil(height / line_height);

	return lines;
}
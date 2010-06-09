var $j = jQuery.noConflict();

$j(document).ready(function(){
	
	// Hiding all force pass/fail controls
	$j(".error_review").hide();

	// Toggle review controls
	$j(".manual-review").click(function(event) {
			$j(this).text($j(this).text() == 'DETAILS' ? 'CLOSE' : 'DETAILS');
			$j(this).next($j(".error_review")).slideToggle("slow");
			return false;
	})

	// FILTERING
  $j("#filter input:checkbox").click(function(e) {
      var pass = $j("tr, td").filter('.pass');
			var fail = $j("tr, td").filter('.failed');
			var review = $j("tr, td").filter('.review');
			var nottested = $j("tr, td").filter('.not_tested');
      
			// If passed checkbox is checked
      if ($j("#fieldPass").is(":checked")) {
			//show passed fields
				pass.show();
			} else {
				pass.hide();
			}
			
			// If review checkbox is checked
      if ($j("#fieldReview").is(":checked")) {
			//show passed fields
				review.show();
			} else {
				review.hide();
			}
			
			// If fail checkbox is checked
      if ($j("#fieldFailed").is(":checked")) {
			//show passed fields
				fail.show();
			} else {
				fail.hide();
			}
			
			// If not tested checkbox is checked
      if ($j("#fieldNotTested").is(":checked")) {
			//show passed fields
				nottested.show();
			} else {
				nottested.hide();
			}
  });

	// SCROLLING	
	//$j('a.error_link').click(function() {
	//		var $errorid = (this).attr("id");
	//		var $target = $j('xml_frame').find('div:attr(id, $errorid)');
	//    $j('#xml_frame').scrollTo( $target, {axis:'x'});
	//});
  
});

function update_error_class(content_error_id) {
//  console.log('update');
//  console.log(content_error_id);
  var selector = '#' + content_error_id + ' .result';
  var select_control = $j(selector + ' select');
  set_error_class($j(selector), select_control.val());
}

function set_error_class(element, value) {
//  console.log('set');
//  console.log(value);
//  console.log(element);
  element.removeClass('review');
  element.removeClass('passed');
  element.removeClass('failed');
  element.addClass(value);
}

function reset_error(content_error_id) {
//  console.log('reset');
//  console.log(content_error_id);
  alert('failed to set state for ' + content_error_id)
}

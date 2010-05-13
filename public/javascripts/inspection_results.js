var $j = jQuery.noConflict();

$j(document).ready(function(){
	// Hiding all force pass/fail controls
  $j(".field_review_controls").hide();

	// Toggle review controls
	$j(".manual-review").click(function(event) {
			$j(this).text($j(this).text() == 'OPEN' ? 'CLOSE' : 'OPEN');
			$j(this).parents().next(".field_review_controls").slideToggle("slow");
			return false;
	})

	// FILTERING
  $j("#filter input:checkbox").click(function(e) {
      var pass = $j(".module_field").filter('.pass');
			var fail = $j(".module_field").filter('.fail');
			var review = $j(".module_field").filter('.review');
			var nottested = $j(".module_field").filter('.not_tested');
      
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
  
  
});

// Check the status of each field within a given module

// If all individual fields pass: set the overall inspection status to pass

// Else (one or more fields result in review or fail) set the overall inspection 
// status to pending

// Each time a force pass or fail is submitted on an individual field 
// within a module check to see whether all individual fields pass and 
// update overall module inspection status

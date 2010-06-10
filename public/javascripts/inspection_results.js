var $j = jQuery.noConflict();

$j(document).ready(function(){
  
  // Hiding all force pass/fail controls
  $j(".error_review").hide();

  // Toggle review controls
  $j(".manual-review").click(function(event) {
      toggle_details(this);
      return false;
  })

  // FILTERING
  $j("#filter input:checkbox").click(function(e) {
    var input = e.target;
    var type = input.name;
    var rows = $j("tr." + type + " td");
    // If passed checkbox is checked
    if (input.checked) {
      //show passed fields
      rows.show();
    } else {
      rows.hide();
    }
  });

  set_overall_content_inspection_status();
  set_manual_assignment();

  // SCROLLING  
  //$j('a.error_link').click(function() {
  //    var $errorid = (this).attr("id");
  //    var $target = $j('xml_frame').find('div:attr(id, $errorid)');
  //    $j('#xml_frame').scrollTo( $target, {axis:'x'});
  //});
  
});

function update_error_class(content_error_id) {
//  console.log('update');
//  console.log(content_error_id);
  var selector = '#' + content_error_id;
  var select_control = $j(selector + ' select');
  set_error_class($j(selector), select_control.val());
  set_overall_content_inspection_status();
  set_content_inspection_summary();
  set_manual_assignment();
}

function set_error_class(element, value) {
//  console.log('set');
//  console.log(value);
//  console.log(element);
  element.removeClass('review passed failed');
  element.addClass(value);
}

function reset_error(content_error_id) {
//  console.log('reset');
//  console.log(content_error_id);
  alert('failed to set state for ' + content_error_id)
}

function set_overall_content_inspection_status() {
  var error_rows = $j('.scrollContent tr');
  var inspection_status = $j('#content_inspection_status');
  var status_code = $j('#content_inspection_status .status_code');
//  console.log(error_rows)
//  console.log(inspection_status)
//  console.log(status_code)
  if (error_rows.hasClass('review')) {
    status_code.text('Pending');
    set_error_class(inspection_status, 'review');
  } else if (error_rows.hasClass('failed')) {
    status_code.text('Failed');
    set_error_class(inspection_status, 'failed');
  } else {
    status_code.text('Passed');
    set_error_class(inspection_status, 'passed');
  } 
}

function set_content_inspection_summary() {
  var error_rows = $j('.scrollContent tr');
  ['passed','failed','pending'].each( function(e) {
    var error_state = (e == 'pending') ? 'review' : e;
    var count = error_rows.filter('.' + error_state).size();
    $j('#content_inspection_summary .' + e).text(count);
  })
}

function set_manual_assignment() {
  var failed = $j('.scrollContent tr').hasClass('failed');
  var fields = $j('#assign_test_state_manually form :input');
  if (failed) {
    fields.attr('disabled','true');
  } else {
    fields.attr('disabled','');
  }
}

function toggle_details(element) {
  var content_error_row = $j(element).closest('tr');
  $j(content_error_row).next('tr').find('.error_review').slideToggle("slow");
  $j(element).toggleClass('open closed')
}

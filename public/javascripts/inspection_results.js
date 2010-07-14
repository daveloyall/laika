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
  $j(".section-errors-filter input:checkbox").click(function(e) {
    var input = e.target;
    var type = input.name;
    var rows = $j("tr." + type + " td");
    var detail_rows = $j("tr." + type + "_details td");
    // If passed checkbox is checked
    if (input.checked) {
      //show passed fields
      rows.show();
      detail_rows.show();
    } else {
      rows.hide();
      // and hide their detail rows in case they were open
      detail_rows.hide();
    }
  });

  set_overall_inspection_status('#xml_validation_inner');
  set_overall_inspection_statuses();
  set_manual_assignment();

  // LOCATION SCROLLING  
  // onclick="$j('#xml_frame').scrollTo( $j('div#error_<%=error_id%>'));"
  $j('a.error_link').click(function() {
//      console.log(this);
//      console.log(this.id);
      var errorid = this.id.replace(/content_error_\d+_link_to_/,'');
//      console.log(errorid);
      var target = $j('#xml_frame #' + errorid);//.find('div:attr(id, errorid)');
//      console.log(target);
      $j('#xml_frame').scrollTo( target, 500, {axis:'y'} );//, {axis:'x'});
  });
  
});

function set_overall_inspection_statuses() {
  set_overall_inspection_status('#content_inspection_inner');
  set_overall_inspection_status('#umls_validation_inner');
}

function set_inspection_summaries() {
  set_inspection_summary('#content_inspection');
  set_inspection_summary('#umls_validation');
}

function update_error_class(content_error_id) {
//  console.log('update');
//  console.log(content_error_id);
  var selector = '#' + content_error_id;
  var select_control = $j(selector + ' select');
  var error_class = select_control.val();
  set_error_class($j(selector), error_class);
  set_error_class($j(selector + '_details'), error_class + '_details');
  set_overall_inspection_statuses();
  set_inspection_summaries();
  set_manual_assignment();
}

function set_error_class(element, value) {
//  console.log('set');
//  console.log(value);
//  console.log(element);
  element.removeClass('review passed failed review_details passed_details failed_details');
  element.addClass(value);
}

function reset_error(content_error_id) {
//  console.log('reset');
//  console.log(content_error_id);
  alert('failed to set state for ' + content_error_id)
}

function set_overall_inspection_status(tab_id) {
  var error_rows = $j(tab_id + ' .scrollContent tr');
  var inspection_status = $j(tab_id + ' .section-errors-status');
  var status_code = $j(tab_id + ' .section-errors-status .status_code');
//  console.log('set_overall_inspection_status for: ' + tab_id)
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

function set_inspection_summary(tab_id) {
  var error_rows = $j(tab_id + '_inner .scrollContent tr');
//  console.log('set_inspection_summary for: ' + tab_id);
//  console.log(error_rows);
  ['passed','failed','pending'].each( function(e) {
    var error_state = (e == 'pending') ? 'review' : e;
    var count = error_rows.filter('.' + error_state).size();
    var summary = $j(tab_id + '_summary .' + e);
//  console.log(summary);
//  console.log(count);
    summary.text(count);
  });
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

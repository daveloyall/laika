document.observe('dom:loaded', function() {
  $$('a.checklist').each(function(e) {
    e.observe('click', function(event) {
      window.open(this.href,"checklist");
      event.stop();
    })
  })
})

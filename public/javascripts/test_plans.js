document.observe('dom:loaded', function() {
  $$('a.checklist').each(function(e) {
    e.observe('click', function(event) {
      window.open(this.href,"checklist");
      event.stop();
    })
  })
})

    function scroll_to_module(id, time)
    {
      new Effect.ScrollTo(id,{duration:time});
    }

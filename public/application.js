$(function() {
  
  if (ip_parts) {
    $("#edit-form, #delete-form").
      append('<input type="hidden" name="ip_first" value="'+ip_parts[0]+'">').
      append('<input type="hidden" name="ip_last" value="'+ip_parts[1]+'">');
  }
  
  $("#delete-form").submit(function() {
    return confirm("Are you sure? There is no undo (yet).");
  });
  
  $("#delete-form").hide();
  $("#delete-form").before('<div id="delete-link"><p><a href="#">Delete this version</a></p></div>');
  $("#delete-link a").click(function() {
    $("#delete-link").hide();
    $("#delete-form").show();
    return false;
  });
  
});
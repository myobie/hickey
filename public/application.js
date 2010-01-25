$(function() {
  
  $("#delete-form").submit(function() {
    return confirm("Are you sure? There is no undo (yet).");
  });
  
  if (ip_parts) {
    $("#edit-form").append('<input type="hidden" name="'+ip_parts[0]+'" value="'+ip_parts[1]+'">');
  }
  
});
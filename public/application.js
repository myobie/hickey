$(function() {
  
  $("#delete-form").submit(function() {
    var answer = confirm("Are you sure? There is no undo (yet).");
    
    return answer;
  });
  
});
// PPKs cookie functions
var Cookie = {
  set: function(name,value,days) {
    var expires;
    
    if (days) {
      var date = new Date();
      date.setTime(date.getTime()+(days*24*60*60*1000));
      expires = "; expires="+date.toGMTString();
    } 
    else expires = "";
    
    document.cookie = name+"="+value+expires+"; path=/";
  },

  get: function(name) {
    var nameEQ = name + "=";
    var ca = document.cookie.split(';');
    for(var i=0;i < ca.length;i++) {
      var c = ca[i];
      while (c.charAt(0)==' ') c = c.substring(1,c.length);
      if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
    }
    return null;
  },

  remove: function(name) {
    createCookie(name,"",-1);
  }
};

var Pages = {
  list: [],
  filter: function(what) {
    var regex = new RegExp(".*" + what.replace(/[^a-zA-Z0-9-_]/, "") + ".*");
    
    var results = [];
    for (var i=0; i < Pages.list.length; i++) {
      if (! Pages.list[i].text.match(regex)) {
        results.push(Pages.list[i].id);
      }
    };
    return results;
  }
};

var EditForm = {};

$(function() {
  
  // Edit & Delete
  
  var edit_form = $("#edit-form");
  var delete_form = $("#delete-form");
  
  if (typeof ip_parts != "undefined") {
    $("#edit-form, #delete-form").
      append('<input type="hidden" name="ip_first" value="'+ip_parts[0]+'">').
      append('<input type="hidden" name="ip_last" value="'+ip_parts[1]+'">');
  }
  
  delete_form.submit(function() {
    return confirm("Are you sure? There is no undo (yet).");
  });
  
  edit_form.submit(function() {
    Cookie.set("saved_editor_name", $("#page_editor_name").val(), 365);
  });
  
  delete_form.hide();
  delete_form.before('<div id="delete-link"><p><a href="#">Delete this version</a></p></div>');
  $("#delete-link a").click(function() {
    $("#delete-link").hide();
    $("#delete-form").show();
    return false;
  });
  
  $("#edit-form p:last").append('or <button id="preview" type="submit">Preview</button>');
  
  $("#preview").click(function() {
    var action = edit_form.attr("action");
    
    var change_back = function() {
      console.log(action);
      edit_form.attr("action", action);
      edit_form.attr("target", "");
    };
    
    edit_form.attr("action", "/preview");
    edit_form.attr("target", "_blank");
    
    setTimeout(change_back, 100); // this is crazy!
  });
  
  // Pages search
  if ($("#pages").length === 1) {
    $("#pages").before('<input type="search" id="filter" placeholder="Filter pages">');
    
    $("#pages li").each(function() {
      Pages.list.push({ text: $(this).find("a").text().toLowerCase(), id: "#"+this.id });
    });
    
    $("#filter").keyup(function() {
      $("ul li:hidden").show();
      if (this.value == "") { return; }
      $(Pages.filter(this.value).join(", ")).hide();
    });
  }
  
  // Preview click to close
  $("#content.preview + #meta p").html('<a href="#" onclick="window.close()">Close this window</a>');
  
});
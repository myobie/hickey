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

$(function() {
  
  // Edit & Delete
  
  if (typeof ip_parts != "undefined") {
    $("#edit-form, #delete-form").
      append('<input type="hidden" name="ip_first" value="'+ip_parts[0]+'">').
      append('<input type="hidden" name="ip_last" value="'+ip_parts[1]+'">');
  }
  
  $("#delete-form").submit(function() {
    return confirm("Are you sure? There is no undo (yet).");
  });
  
  $("#edit-form").submit(function() {
    Cookie.set("saved_editor_name", $("#page_editor_name").val(), 365);
  });
  
  $("#delete-form").hide();
  $("#delete-form").before('<div id="delete-link"><p><a href="#">Delete this version</a></p></div>');
  $("#delete-link a").click(function() {
    $("#delete-link").hide();
    $("#delete-form").show();
    return false;
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
  
});
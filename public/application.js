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

// pages list filter
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

// on dom load
$(function() {
  
  // Version chooser
  $("#versions").change(function() { window.location = this.value; });
  
  // Edit & Delete
  
  if ($("#edit-form").length > 0) {
    
    var edit_form = $("#edit-form");
    var delete_form = $("#delete-form");

    // add the ip checking fields
    if (typeof ip_parts != "undefined") {
      $("#edit-form, #delete-form").
        append('<input type="hidden" name="ip_first" value="'+ip_parts[0]+'">').
        append('<input type="hidden" name="ip_last" value="'+ip_parts[1]+'">');
    }

    // confirm on delete
    delete_form.submit(function() {
      return confirm("Are you sure? There is no undo (yet).");
    });

    // cache the editor's name
    edit_form.submit(function() {
      Cookie.set("saved_editor_name", $("#page_editor_name").val(), 365);
    });

    // hide delete and create a link to show it
    delete_form.hide();
    delete_form.before('<div id="delete-link"><p><a href="#">Delete this version</a></p></div>');
    $("#delete-link a").click(function() {
      $("#delete-link").hide();
      $("#delete-form").show();
      return false;
    });

    // add a preview button
    $("#edit-form p:last").append('or <button id="preview" type="submit">Preview</button>');

    // wire up the preview button
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
    
    // make it possible to tab in the edit textarea
    $("#page_body").keydown(function(event) {
      console.log(event.which, event.metaKey);
      if (event.which == 9 || (event.which == 221 && event.metaKey)) {
        event.preventDefault();
        var starting_pos, ending_pos, new_value;

        if (this.selectionStart == this.selectionEnd) {

          var first_half = this.value.substring(0, this.selectionStart);
          var second_half = this.value.split(first_half)[1] || "";
          var lines = first_half.split("\n");
          var last_line = lines[lines.length-1];
          var spaces = last_line.length % 2 ? " " : "  ";

          starting_pos = ending_pos = this.selectionStart + spaces.length;
          new_value = first_half + spaces + second_half;

        } else {

          var first_third = this.value.substring(0, this.selectionStart);
          var second_third = this.value.substring(this.selectionStart, this.selectionEnd);
          var third_third = this.value.split(first_third + second_third)[1] || "";

          var lines = first_third.split("\n");     // break into lines
          var last_line = lines.pop() || "";       // grab the last one so we can put it into the middle
          first_third = lines.join("\n");          // join them back together

          second_third = last_line + second_third; // put that line over into the second one

          // get ready to add spaces to the front of all the lines
          var lines2 = second_third.split("\n"); // get the lines
          var new_second_third_lines = []; // start an accumulator

          for (var i = 0; i < lines2.length; i++) {
            new_second_third_lines.push("  "  + lines2[i]);
          };

          // recombine
          new_value = first_third + "\n" + new_second_third_lines.join("\n") + third_third;
          // reset the selection based on the number of lines
          starting_pos = this.selectionStart + 2;
          ending_pos = this.selectionEnd + (lines2.length * 2);
        }

        this.value = new_value;
        this.setSelectionRange(starting_pos, ending_pos);
      }
    });
  }
  
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

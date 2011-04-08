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
        // console.log(action);
        edit_form.attr("action", action);
        edit_form.attr("target", "");
      };

      edit_form.attr("action", "/preview");
      edit_form.attr("target", "_blank");

      setTimeout(change_back, 100); // this is crazy!
    });
    
    // make it possible to tab in the edit textarea
    var keys_we_care_about = function(event) {
      return event.which == 9 ||
             (event.which == 221 && event.metaKey) ||
             (event.which == 219 && event.metaKey) ||
             event.which == 13;
    }

    $("#page_body").keydown(function(event) {
      // console.log(event.which, event.metaKey);
      if (keys_we_care_about(event)) {
        event.preventDefault();
        var starting_pos, ending_pos, new_value = this.value, pieces = [], this_line = "", lines = [], spaces = "  ",
            is_selection = this.selectionStart != this.selectionEnd;

        if (!is_selection) {

          var first_half = this.value.substring(0, this.selectionStart);
          var second_half = this.value.substring(this.selectionEnd, this.value.length);
          pieces = [first_half, second_half];
          var lines = pieces[0].split("\n");
          this_line = lines[lines.length-1];

        } else {

          var first_third = this.value.substring(0, this.selectionStart);
          var second_third = this.value.substring(this.selectionStart, this.selectionEnd);
          var third_third = this.value.substring(this.selectionEnd, this.value.length);
          pieces = [first_third, second_third, third_third];

          lines = pieces[0].split("\n");     // break into lines
          this_line = lines.pop() || "";       // grab the last one so we can put it into the middle
          pieces[0] = lines.join("\n");          // join them back together

          pieces[1] = this_line + pieces[1]; // put that line over into the second one
        }

        // tab or command + ]
        if (event.which == 9 || (event.which == 221 && event.metaKey)) {

          if (!is_selection) {

            spaces = this_line.length % 2 ? " " : "  ";
            starting_pos = ending_pos = this.selectionStart + spaces.length;
            new_value = pieces.join(spaces);

          } else {

            // get ready to add spaces to the front of all the lines in the
            // selection
            var lines_to_indent = pieces[1].split("\n"); // get the lines
            var indented_lines = []; // start an accumulator

            for (var i = 0; i < lines_to_indent.length; i++) {
              indented_lines.push("  "  + lines_to_indent[i]);
            };

            // recombine
            new_value = pieces[0] + "\n" + indented_lines.join("\n") + pieces[2];
            // reset the selection based on the number of lines
            starting_pos = this.selectionStart + 2;
            ending_pos = this.selectionEnd + (lines_to_indent.length * 2);

          }

        }

        // return
        if (event.which == 13) {

          // console.log(this_line);

          if (!is_selection) {

            var spaces_at_the_beginnig_of_line = this_line.match(/^( *).*$/)[1];
            pieces[1] = spaces_at_the_beginnig_of_line + pieces[1];
            new_value = pieces.join("\n");
            var amount = spaces_at_the_beginnig_of_line.length + 1;
            starting_pos = this.selectionStart + amount;
            ending_pos = this.selectionEnd + amount;

          } else {

            pieces[0] += this_line;
            pieces[1] = "\n";
            new_value = pieces.join("");
            var amount = this_line == "" ? 0 : 1;
            starting_pos = ending_pos = this.selectionStart + amount;

          }

        }

        // command + [
        if (event.which == 219 && event.metaKey) {
          var lines_to_outdent = pieces[1].split("\n");
          var outdented_lines = [];

          for (var i = 0; i < lines_to_outdent.length; i++) {
            outdented_lines.push(lines_to_outdent[i].replace(/^( {1,2})/, ""));
          }

          // recombine
          new_value = pieces[0] + "\n" + outdented_lines.join("\n") + pieces[2];
          // reset the selection based on the number of lines
          var number_of_spaces = outdented_lines[0].match(/^( *).*$/)[1].length;
          var amount = number_of_spaces < 2 ? number_of_spaces : 2;
          starting_pos = this.selectionStart - amount;
          ending_pos = this.selectionEnd - (lines_to_outdent.length * 2) + 1;
        }

        // console.log(pieces);

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

  // Export show and hide
  $("#export").prepend('<a href="#" onclick="$(\'#export form\').show(); $(this).hide(); return false">Export</a>');
  $("#export form").hide();

});

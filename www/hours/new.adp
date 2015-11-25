<master>
<property name="doc(title)">@page_title;literal@</property>
<property name="context">#intranet-timesheet2.context#</property>
<property name="main_navbar_label">timesheet2_timesheet</property>
<property name="left_navbar">@left_navbar_html;literal@</property>
<property name="show_context_help_p">@show_context_help_p;literal@</property>

<%= [im_box_header $page_title] %>

<form name=timesheet method=POST action=new-2>
@export_form_vars;noquote@

<table>
	  <if @edit_hours_p@ eq "f">
	  <tr>
		<td colspan="7">
		<font color=red>
		<h3>@edit_hours_closed_message;noquote@</h3>
		</font>
		</td>
	  </tr>
	  </if>

	  @forward_backward_buttons;noquote@

<if @ctr@>

	    <tr class=rowtitle>
		<th>#intranet-timesheet2.Project_name#</th>
		<th></th>

		<if @show_week_p@ eq 0>
		<th>#intranet-timesheet2.Hours#	</th>
		<th>#intranet-timesheet2.Work_done#</th>
<if @internal_note_exists_p@>
		<th><%= [lang::message::lookup "" intranet-timesheet2.Internal_Comment "Internal Comment"] %></th>
</if>
<if @materials_p@>
		<th><%= [lang::message::lookup "" intranet-timesheet2.Service_Type "Service Type"] %></th>
</if>
		</if>
		<else>
		@week_header_html;noquote@
		</else>
	    </tr> 
	    @results;noquote@
	    <tr>
		<td></td>
		<td colspan="99">
		<if @edit_hours_p@ eq "t">
		    <INPUT TYPE=Submit VALUE="#intranet-timesheet2.Add_hours#">
		</if>
		</td>
	    </tr>

</if>
<else>
	<tr>
	<td>
	<%= [lang::message::lookup "" intranet-timesheet2.Not_Member_of_Projects "
	    You are not a member of any project where you could log your hours.<p>
	    Please contact the project manager of your project(s) to include you in 
	    the list of project members.
	"] %>
	</td>
	</tr>
</else>


</table>
</form>

<script type="text/javascript">
	// Scripts for fold-in/fold out 
	var obj_nested_list = [],
    	    child_arr = [],
	    obj;

	    @js_objects;noquote@
	    @js_obj_list;noquote@

         function getParent(id) {
	 	  for (var i = 0; i < obj_list.length; i++) {
                     obj = obj_list[i];
                     if (obj.id == id) {
                        return obj.parent;
                     }
                  }
		  return ''; 
         }

	 function fill_with_children(children_arr, parent_id) {
	 	  // children_arr is empty in first call 
		  for (var i = 0; i < obj_list.length; i++) {
		  	 obj = obj_list[i];
			 if (obj.parent == parent_id) {
            		    children_arr.push(obj);
			    obj.children = [];
			    fill_with_children(obj.children, obj.id);
			 }
    		   }
	     }

         function fill_with_direct_children(children_arr, parent_id) {
                 // console.log('Getting direct childs for parent_id:' + parent_id);
                 for (var i = 0; i < obj_list.length; i++) {
                     obj = obj_list[i];
                     if (obj.parent == parent_id) {
                        children_arr.push(obj);
                     }
                  }
                 // console.log('Leaving "fill_with_direct_children":' + children_arr + 'lebth:' + children_arr.length);			   
          }

		function setChildArr(list) {
			for (var i = 0; i < list.length; i++) {
       	    	    	    child_arr.push(list[i].id);
			    if (list[i].children.length > 0) {
			   	 setChildArr(list[i].children);
        		    }
    		    	};
		};


          // Change visibility of row
          function toggle_visibility(row_id_project, project_id) {
             // console.log('handling project_id: ' + project_id);
             obj_nested_list = [];
             child_arr = [];
             fill_with_children(obj_nested_list, project_id);
             // console.log('obj_nested_list: '+ obj_nested_list);
             setChildArr(obj_nested_list);
             // console.log('Found the following children:' + child_arr);
		   if (document.getElementById(project_id).getAttribute("fold_status") == 'o') {
		   	 // current status is 'open', hide all childs 
			 for (var i = 0; i < child_arr.length; i++) {
			     if ( document.getElementById(child_arr[i]) != null) {
			          document.getElementById(child_arr[i]).className = document.getElementById(child_arr[i]).className.replace('row_visible', 'row_hidden');			    
			      };
               		 };
			 // Change BG image 
			 if ( document.getElementById(row_id_project) != null) {
	 			document.getElementById(row_id_project).style.backgroundImage = 'url(/intranet/images/plus_9.gif)'
		         };
			 // Toggle custom attribute 
			 if ( document.getElementById(project_id) != null) {
			 	 document.getElementById(project_id).setAttribute("fold_status", "c")
			 };
			 // Set this project to close on server  
			 $(this).updateFolds(project_id, 'c');
		   } else {
		   	// change status from "closed" to "open": Un-hide all childs elements with a parent that is not closed    
               		for (var i = 0; i < child_arr.length; i++) {		
			    var parent_id = getParent(child_arr[i]);			    
			    // Make direct childs ALWAYS visible 
			    if (parent_id == project_id) {
			       if ( document.getElementById(child_arr[i]) != null) {
			       	  document.getElementById(child_arr[i]).className = document.getElementById(child_arr[i]).className.replace('row_hidden', 'row_visible');
			       };
			    } else {
			    	 // Only show when parent is not marked as "c" then do not show  
				 console.log('Found parent: ' + parent_id + 'for child:' + i);
				 if ( document.getElementById(parent_id) != null) {
				      if ("c" != document.getElementById(parent_id).getAttribute("fold_status")) {
				      	   if ( document.getElementById(child_arr[i]) != null ) {
					      document.getElementById(child_arr[i]).className = document.getElementById(child_arr[i]).className.replace('row_hidden', 'row_visible');
					   };
			      	      };	   				 
				 };
			    };  
			};
			if ( document.getElementById(project_id) != null) {
			   document.getElementById(project_id).setAttribute("fold_status", "o")
			};
			if ( document.getElementById(row_id_project) != null) {
			   document.getElementById(row_id_project).style.backgroundImage = 'url(/intranet/images/minus_9.gif)'
			};
			$(this).updateFolds(project_id, 'o');			
		   };
          };

		// Have jquery handle XHR request
		jQuery.fn.extend({
		    updateFolds: function (object_id, action) {
		    		// console.log('arr:' + arr);
				// var object_ids = arr.join(",");
				var object_ids = object_id;
				var data = { page_url: '/intranet-timesheet2/hours/new', open_p: action, object_ids: object_ids };
		    		$.ajax({
					type:  'POST',
					url:   '/intranet/biz-object-tree-open-close',
					data:  data
				});				
				return '1';
    		    }
		});

</script>

<%= [im_box_footer] %>

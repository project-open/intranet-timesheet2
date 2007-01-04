<master src="../../../intranet-core/www/master">
<property name="title">#intranet-timesheet2.Timesheet#</property>
<property name="context">#intranet-timesheet2.context#</property>
<property name="main_navbar_label">timesheet2_timesheet</property>

<if @edit_hours_p@ eq "f">
<font color=red>
<h3>@edit_hours_closed_message@</h3>
</font>
</if>


<table border=0 cellspacing=0 cellpadding=0 width="100%">
<tr valign=top>
  <td width="50%">

	<form action=new method=post>
	<%= [export_form_vars return_url julian_date project_id_list]  %>
	<table border=0 cellpadding=1 cellspacing=1>
	  <tr class=rowtitle>
	    <th colspan=99>Timesheet Filters</th>
	  </tr> 
	  <tr>
	    <td>#intranet-core.Project_name#</td>
	    <td><%= [im_project_select -exclude_subprojects_p 1 project_id $project_id_for_default "open"] %></td>
	    <td>
	      <input type=submit value="Go">
	    </td>
	  </tr>
	</table>

	</form>

  </td>
  <td width="50%">

	<table border=0 cellpadding=1 cellspacing=1>
	<tr class=rowtitle>
	  <td class=rowtitle>#intranet-timesheet2.Other_Options#</td>
	</tr>
	<tr>
	  <td>
	    <li>
	      <a href=@different_date_url;noquote@>
	        #intranet-timesheet2.lt_Log_hours_for_a_diffe#
	      </a>

	    <li>
	      <a href=@absences_url;noquote@>
	        @absences_link_text@
	      </a>


<% if {[im_permission $user_id view_projects_all]} { %>
	    <li>
	      <a href=@different_project_url;noquote@>
		#intranet-timesheet2.lt_Add_hours_on_other_pr#
	      </A>
<% } %>
<% if { ![empty_string_p $return_url] } { %>
	    <li>
	      <a href="@return_url@">#intranet-timesheet2.lt_Return_to_previous_pa#</a>
<% } %>
	  </td>
	</tr>
	</table>

  </td>
</tr>
</table>

<br>

<form method=POST action=new-2>
@export_form_vars;noquote@

<table border=0 cellpadding=1 cellspacing=1>
 <tr class=rowtitle>
  <th>#intranet-timesheet2.Project_name#</th>
  <th>#intranet-timesheet2.Hours#	</th>
  <th>#intranet-timesheet2.Work_done#   </th>
 </tr> 
@results;noquote@
  <tr>
    <td></td>
    <td colspan=99>
<if @edit_hours_p@ eq "t">
      <INPUT TYPE=Submit VALUE="#intranet-timesheet2.Add_hours#">
</if>
    </td>
  </tr>
</table>

</form>

<master src="../../../intranet-core/www/master">
<property name="title">@page_title@</property>
<property name="context">#intranet-timesheet2.context#</property>
<property name="main_navbar_label">timesheet2_timesheet</property>

<div class="filter-list">
   <div class="filter">
      <div class="filter-block">
        <div class="filter-title">
	    Timesheet Filters
        </div>

	<form action=new method=GET>
	<!-- don't include return_url in the export_form_vars, as it includes the old user -->
	<%= [export_form_vars julian_date project_id_list show_week_p]  %>
	<table border=0 cellpadding=1 cellspacing=1>
	<tr>
	    <td><%= [lang::message::lookup "" intranet-core.Project_br_Name "Project<br>Name"] %></td>
	    <td><%= [im_project_select -include_empty_p 1 -include_empty_name "" -exclude_subprojects_p 1 project_id $project_id_for_default "open"] %></td>
	</tr>

<if @add_hours_all_p@>
	<tr>
	    <td><%= [lang::message::lookup "" intranet-core.Log_hours_for_user "Log Hours<br>for User"] %></td>
	    <td><%= [im_user_select -include_empty_p 1 -include_empty_name "" user_id_from_search $user_id_from_search] %></td>
	</tr>
</if>

	<tr><td></td><td><input type=submit value="Go"></td></tr>
	</table>
	</form>
      </div>

      <div class="filter-block">
         <div class="filter-title">
            #intranet-timesheet2.Other_Options#
         </div>

	 <ul>
	    <li>
	      <a href=@different_date_url;noquote@>
	        #intranet-timesheet2.lt_Log_hours_for_a_diffe#
	      </a>
            </li>

<if @user_id@ eq @user_id_from_search@>
<!-- don't show the "New Absence" link when logging hours for another person -->
	    <li>
	      <a href=@absences_url;noquote@>
	        @absences_link_text@
	      </a>
            </li>
</if>

<% if {[im_permission $user_id_from_search view_projects_all]} { %>
	    <li>
	      <a href=@different_project_url;noquote@>
		#intranet-timesheet2.lt_Add_hours_on_other_pr#
	      </A>
            </li>
<% } %>
<% if { ![empty_string_p $return_url] } { %>
	    <li>
	      <a href="@return_url@">#intranet-timesheet2.lt_Return_to_previous_pa#</a>
<% } %>
            </li>

	    <!-- Dynamically added menu links -->
	    @menu_links_html;noquote@

         </ul>
      </div>
   </div> <!-- filter -->

   <div class="fullwidth-list">
      <%= [im_box_header $page_title] %>

<form method=POST action=new-2>
@export_form_vars;noquote@

<table border=0 cellpadding=1 cellspacing=1>

	  <if @edit_hours_p@ eq "f">
	  <tr>
		<td colspan=7>
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
	
		<if @show_week_p@ eq 0>
		<th>#intranet-timesheet2.Hours#	</th>
		<th>#intranet-timesheet2.Work_done#</th>
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
		<td colspan=99>
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

     <%= [im_box_footer] %>
   </div>
   <div class="filter-list-footer"></div>

</div>




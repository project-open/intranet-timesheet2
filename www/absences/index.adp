<master src="../../../intranet-core/www/master">
<property name="title">Absences</property>
<property name="@context@">context</property>
<property name="main_navbar_label">timesheet2_absences</property>

<div class="filter-list">
   <div class="filter">
      <div class="filter-block">
            <div class="filter-title">
	       #intranet-timesheet2.Filter_Absences#
	    </div>
         <%= $filter_html %>
      </div>
      <if @admin_html@>
         <div class="filter-block">
            <div class="filter-title">
	       #intranet-timesheet2.Admin_Absences#
	    </div>
            <%= $admin_html %>
         </div>
      </if>
   </div>

   <div class="fullwidth-list">
      <%= [im_box_header $page_title] %>
         <table>
            <%= $table_header_html %>
            <%= $table_body_html %>
            <%= $table_continuation_html %>
         </table>
     <%= [im_box_footer] %>
   </div>
   <div class="filter-list-footer"></div>

</div>


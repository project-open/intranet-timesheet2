<master src="../../intranet-core/www/master">
<property name="title">Weekly Hours</property>
<property name="context">context</property>
<property name="main_navbar_label">finance</property>

<div class="filter-list">
   <div class="filter">
      <div class="filter-block">
        <div class="filter-title">
	    #intranet-timesheet2.Admin#
        </div>
        <ul>
	@admin_html;noquote@
        </ul>
      </div>
   </div> <!-- filter -->

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

<master src="../../../intranet-core/www/master">
<property name="title">Absences</property>
<property name="@context@">context</property>
<property name="main_navbar_label">timesheet2_absences</property>
<property name="left_navbar">@left_navbar_html;noquote@</property>

<div class="fullwidth-list" id="fullwidth-list">
	<table>
	    <%= $table_header_html %>
	    <%= $table_body_html %>
	    <%= $table_continuation_html %>
	</table>
</div>

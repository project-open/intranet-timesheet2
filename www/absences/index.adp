<master src="../../../intranet-core/www/master">
<property name="title">Absences</property>
<property name="context">context</property>
<property name="main_navbar_label">timesheet2_absences</property>

<%= $absence_filter_html %>

<table width=100% cellpadding=2 cellspacing=2 border=0>
  <%= $table_header_html %>
  <%= $table_body_html %>
  <%= $table_continuation_html %>
</table>

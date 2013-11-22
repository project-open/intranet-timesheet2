<master src="../../../intranet-core/www/master">
<property name="title">@page_title@</property>
<property name="@context@">@context;noquote@</property>
<property name="main_navbar_label">timesheet2_absences</property>

<if @message@ not nil>
  <div class="general-message">@message@</div>
</if>

<%= [im_box_header $page_title] %>
<formtemplate id="leave_entitlement"></formtemplate></font>
<%= [im_box_footer] %>

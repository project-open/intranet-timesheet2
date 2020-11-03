<master src="../../../intranet-core/www/master">
<property name="doc(title)">@page_title;literal@</property>
<property name="context">#intranet-timesheet2.context#</property>
<property name="main_navbar_label">timesheet2_timesheet</property>


<script type="text/javascript" <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce;literal@"</if>>
window.addEventListener('load', function() { 
     document.getElementById('list_check_all').addEventListener('click', function() { acs_ListCheckAll('project_list', this.checked) });
});
</script>


<%= [im_box_header $page_title] %>
<listtemplate name="other_projects"></listtemplate>
<%= [im_box_footer] %>

<master src="../../../intranet-core/www/master">
<property name="doc(title)">@page_title;literal@</property>
<property name="context">#intranet-timesheet2.context#</property>
<property name="main_navbar_label">timesheet2_timesheet</property>
<property name="left_navbar">@left_navbar_html;literal@</property>

<if "" ne @message@>
<h1>@header@</h1>

<table width="70%">
   <tr>
      <td>
         <div class="form-error">
            @message;noquote@
         </div>
      </td>
   </tr>
</table>

<p></p>
</if>

<%= [im_table_with_title $page_title $page_body] %>


<master src="../../../intranet-core/www/master">
<property name="title">@page_title;noquote@</property>
<property name="context">context</property>
<property name="main_navbar_label">timesheet2_absences</property>

<%= [im_box_header [_ intranet-timesheet2.Absence]] %>
<form action="new-2.tcl" method=GET>
<%= [export_form_vars absence_id owner_id return_url] %>
<TABLE border=0>
  <TBODY>
  <TR class=rowodd>
    <TD>#intranet-timesheet2.User#</TD>
    <TD><a href="/intranet/users/view?[export_url_vars owner_id#">@owner_name@</a></TD>
  </TR>

<IF @absence_objectified_p@>
  <TR class=rowodd>
    <TD><%= [lang::message::lookup "" intranet-timesheet2.Absence_Title "Title"] %></TD>
    <TD><input type=text name=absence_name value="@absence_name@" size=60></TD>
  </TR>

<!--
  <TR class=rowodd>
    <TD><%= [lang::message::lookup "" intranet-timesheet2.Absence_Status "Absence Status"] %></TD>
    <TD><%= [im_category_select "Intranet Absence Status" absence_status_id $absence_status_id] %></TD>
  </TR>
-->

</IF>

  <TR class=rowodd>
    <TD>#intranet-timesheet2.Absence_Type_1#</TD>
    <TD><%= [im_category_select "Intranet Absence Type" absence_type_id @absence_type_id@] %></TD>
  </TR>

  <TR class=roweven>
    <TD>#intranet-timesheet2.Start_Date#</TD>
    <TD><input name="start_date" type="text" size="30" value=@start_date_pretty@></TD>
  </TR>
  <TR class=rowodd>
    <TD>#intranet-timesheet2.End_Date#</TD>
    <TD><input name="end_date" type="text" size="30" value=@end_date_pretty@></TD>
  </TR>
  <TR class=roweven>
    <TD>#intranet-timesheet2.Description#</TD>
    <TD><textarea name="description" cols="50" rows="5">@description@</textarea></TD>
  </TR>
  <TR class=rowodd>
    <TD>#intranet-timesheet2.Contact_Info#</TD>
    <TD><textarea name="contact_info" cols="50" rows="5">@contact_info@</textarea></TD>
  </TR>
</TBODY></TABLE>
<input type=submit name=submit_save value=#intranet-timesheet2.Save#>&nbsp;
<input type=submit name=submit_del value=#intranet-timesheet2.Delete#>
</form>
<%= [im_box_footer] %>
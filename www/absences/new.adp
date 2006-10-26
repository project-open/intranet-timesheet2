<master src="../../../intranet-core/www/master">
<property name="title">@page_title;noquote@</property>
<property name="context">context</property>
<property name="main_navbar_label">timesheet2_absences</property>

<form action="new-2.tcl" method=GET>
<%= [export_form_vars absence_id owner_id return_url] %>
<TABLE border=0>
  <TBODY>
  <TR>
    <TD class=rowtitle align=middle colSpan=2>#intranet-timesheet2.Absence#</TD></TR>
  <TR class=rowodd>
    <TD>#intranet-timesheet2.User#</TD>
    <TD><a href="/intranet/users/view?[export_url_vars owner_id#">@owner_name@</a></TD></TR>
  <TR class=roweven>
    <TD>#intranet-timesheet2.Start_Date#</TD>
    <TD><input name="start_date" type="text" size="30" value=@start_date@></TD></TR>
  <TR class=rowodd>
    <TD>#intranet-timesheet2.End_Date#</TD>
    <TD><input name="end_date" type="text" size="30" value=@end_date@></TD></TR>
  <TR class=roweven>
    <TD>#intranet-timesheet2.Description#</TD>
    <TD><textarea name="description" cols="50" rows="5">@description@</textarea></TD></TR>
  <TR class=rowodd>
    <TD>#intranet-timesheet2.Contact_Info#</TD>
    <TD><textarea name="contact_info" cols="50" rows="5">@contact_info@</textarea></TD></TR>
  <TR class=rowodd>
    <TD>#intranet-timesheet2.Absence_Type_1#</TD>
    <TD><%= [im_category_select "Intranet Absence Type" absence_type_id @absence_type_id@] %></TD></TR>
</TBODY></TABLE>
<input type=submit name=submit_save value=#intranet-timesheet2.Save#>&nbsp;
<input type=submit name=submit_del value=#intranet-timesheet2.Delete#>
</form>

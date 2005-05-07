# /www/admin/categories/one.tcl
#
# Copyright (C) 2004 various parties
# The code is based on ArsDigita ACS 3.4
#
# This program is free software. You can redistribute it
# and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation;
# either version 2 of the License, or (at your option)
# any later version. This program is distributed in the
# hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.

ad_page_contract {
    Displays and edits an absences.
    @param absence_id absence which should be modified

    @author mai-bee@gmx.net
} {
    absence_id:integer 
}

set user_id [ad_maybe_redirect_for_registration]
set page_title "[_ intranet-timesheet2.View_Absence]"
set context_bar [im_context_bar $page_title]

# Return to this page for edit actions, if not being called
# from another page.
if {[info exists return_url] && "" == $return_url} {
    set return_url [im_url_with_query]
}
set date_format "YYYY-MM-DD"

# ---------------------------------------------------------------
# Permission
# ---------------------------------------------------------------

if {![im_permission $user_id "view_absences_all"]} {
    ad_return_complaint "[_ intranet-timesheet2.lt_Insufficient_Privileg]" "
    <li>[_ intranet-timesheet2.lt_You_dont_have_suffici]"
}

# ---------------------------------------------------------------
# Get Absence Data
# ---------------------------------------------------------------

if {[info exists absence_id] && ![empty_string_p $absence_id]} {
    db_1row absence_data "
    	select 
    		a.owner_id, 
    		description,
    		contact_info,
    		to_char(a.start_date, :date_format) as start_date,
		to_char(a.end_date, :date_format) as end_date,
    		im_name_from_user_id(owner_id) as owner_name, 
    		im_category_from_id(a.absence_type_id) as absence_type 
    	from 
    		im_user_absences a 
    	where 
    		a.absence_id = :absence_id
    	"

# See if current user is owner of absence (if yes, he may edit it)
set admin_html ""
if { $user_id == $owner_id} {
    set admin_html "<input type=submit name=submit value=[_ intranet-timesheet2.Edit]>"
}

# ---------------------------------------------------------------
# Format Absence Data
# ---------------------------------------------------------------

set page_body "
<form action=\"new.tcl\" method=GET>
[export_form_vars absence_id return_url]

<TABLE border=0>
  <TBODY>
  <TR>
    <TD class=rowtitle align=middle colSpan=2>[_ intranet-timesheet2.Absence]</TD></TR>
  <TR class=rowodd>
    <TD>[_ intranet-timesheet2.User]</TD>
    <TD><a href=\"/intranet/users/view=owner_id=$owner_id\">$owner_name</a></TD></TR>
  <TR class=roweven>
    <TD>[_ intranet-timesheet2.Start_Date]</TD>
    <TD>$start_date</TD></TR>
  <TR class=rowodd>
    <TD>[_ intranet-timesheet2.End_Date]</TD>
    <TD>$end_date</TD></TR>
  <TR class=roweven>
    <TD>[_ intranet-timesheet2.Description]</TD>
    <TD>$description</TD></TR>
  <TR class=rowodd>
    <TD>[_ intranet-timesheet2.Contact_Info]</TD>
    <TD>$contact_info</TD></TR>
  <TR class=rowodd>
    <TD>[_ intranet-timesheet2.Absence_Type_1]</TD>
    <TD>$absence_type</TD></TR>
</TBODY></TABLE>
$admin_html
</form>
"
}

#doc_return  200 text/html [im_return_template]

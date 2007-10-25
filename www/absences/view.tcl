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
    absence_id:integer,notnull
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

set absence_objectified_p [db_string ofied {select count(*) from acs_object_types where object_type = 'im_user_absence'}]

# ---------------------------------------------------------------
# Get Absence Data
# ---------------------------------------------------------------


if {[catch {db_1row absence_data "

	select	a.*,
    		to_char(a.start_date, :date_format) as start_date_pretty,
		to_char(a.end_date, :date_format) as end_date_pretty,
    		im_name_from_user_id(owner_id) as owner_name, 
    		im_category_from_id(a.absence_type_id) as absence_type 
    	from	im_user_absences a 
    	where	a.absence_id = :absence_id

"} errmsg]} {
    ad_return_complaint 1 "Unkown Absence: \#$absence_id"
    ad_script_abort
}

# ---------------------------------------------------------------
# Permission
# ---------------------------------------------------------------

if {![im_permission $user_id "view_absences_all"]} {
    if {$owner_id != $user_id} {
	ad_return_complaint "[_ intranet-timesheet2.lt_Insufficient_Privileg]" "
        <li>[_ intranet-timesheet2.lt_You_dont_have_suffici]"
	ad_script_abort
    }
}


# ---------------------------------------------------------------
# Format Absence Data
# ---------------------------------------------------------------

# See if current user is owner of absence (if yes, he may edit it)
set edit_html ""
if {$user_id == $owner_id} {
    set edit_html "
	<TR class=rowplain>
	    <TD></TD>
	    <TD><input type=submit name=submit value=[_ intranet-timesheet2.Edit]></TD>
	</TR>
    "
}


set absence_name_html ""
if {$absence_objectified_p} {

    set absence_name_html "
	  <TR class=roweven>
	    <TD>[lang::message::lookup "" intranet-timesheet2.Absence_Name "Absence Name"]</TD>
	    <TD>$absence_name</TD>
	  </TR>
    "

    if {"" == $absence_name} { set absence_name_html "" }
}


set absence_status_html ""
if {$absence_objectified_p} {

    set absence_status [im_category_from_id $absence_status_id]
    set absence_status_html "
	  <TR class=roweven>
	    <TD>[lang::message::lookup "" intranet-timesheet2.Absence_Status "Absence Status"]</TD>
	    <TD>$absence_status</TD>
	  </TR>
    "

    if {"" == $absence_status} { set absence_status_html "" }
}


set page_body "
<form action=\"new.tcl\" method=GET>
[export_form_vars absence_id return_url]

<TABLE border=0>
  <TBODY>
  <TR>
    <TD class=rowtitle align=middle colSpan=2>[_ intranet-timesheet2.Absence]</TD>
  </TR>
  $absence_name_html
  <TR class=rowodd>
    <TD>[_ intranet-timesheet2.User]</TD>
    <TD><a href=\"/intranet/users/view=owner_id=$owner_id\">$owner_name</a></TD>
  </TR>
  <TR class=roweven>
    <TD>[_ intranet-timesheet2.Start_Date]</TD>
    <TD>$start_date_pretty</TD>
  </TR>
  <TR class=rowodd>
    <TD>[_ intranet-timesheet2.End_Date]</TD>
    <TD>$end_date_pretty</TD>
  </TR>
  <TR class=roweven>
    <TD>[_ intranet-timesheet2.Description]</TD>
    <TD>$description</TD>
  </TR>
  <TR class=rowodd>
    <TD>[_ intranet-timesheet2.Contact_Info]</TD>
    <TD>$contact_info</TD>
  </TR>
  <TR class=rowodd>
    <TD>[_ intranet-timesheet2.Absence_Type_1]</TD>
    <TD>$absence_type</TD>
  </TR>

  $absence_status_html

  $edit_html

</TBODY></TABLE>
</form>
"


#doc_return  200 text/html [im_return_template]

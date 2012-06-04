# /packages/intranet-timesheet2/www/hours/send_pr_info.tcl
#
# Copyright (C) 1998-2004 various parties
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
    Purpose: Send project status info by e-mail

    @author jruiz@competitiveness.com
    @creation-date May 2003
} {
}

set page_title "[_ intranet-timesheet2.Send_project_report]"
set context_bar [im_context_bar [list /intranet/ "[_ intranet-timesheet2.Your_workspace]"] [list "/intranet/dedication_days_pr?report_pr_p=y" "[_ intranet-timesheet2.lt_Dedication_days_repor]"] "[_ intranet-timesheet2.Send_project_report]"]

set project_list [db_list_of_lists get_projects "select pr.group_id as project, \
                                                       ug.short_name as name \
                                                       from IM_PROJECTS pr, USER_GROUPS ug \
                                                       where pr.group_id = ug.group_id \
                                                       order by name"]

append page_body "<form method=POST action=send_pr_info-2>
                  <table>
                     <tr><td colspan=3>[_ intranet-timesheet2.Send_From]<input type=text name=from size=25></td></tr>
                     <tr><td colspan=3>[_ intranet-timesheet2.Send_To]&nbsp;&nbsp;&nbsp;<input type=text name=to size=100> ([_ intranet-timesheet2.comma_separated])</td></tr>"

append page_body "   <tr>
                       <td valign=top>[_ intranet-timesheet2.lt_Select_the_proyects_y]</td>
                       <td>[cm_co_define -format "multiple size=20" projects $project_list]</td>
                       <td valign=middle><input style=\"background:#ECF5E5;\" type=submit value=\"   [_ intranet-timesheet2.Send]   \"></td>
                     </tr>
                  </table>"




doc_return  200 text/html [im_return_template]

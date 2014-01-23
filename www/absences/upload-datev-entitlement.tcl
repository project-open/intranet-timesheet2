# packages/intranet-timesheet2/www/absences/upload-datev.tcl
#
# Copyright (C) 2013 cognovís GmbH
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
    Serve the user a form to upload a new file or URL

    @author malte.sussdorff@cognovis.de
} {
}

set return_url "/intranet-timesheet2/absences"
set user_id [ad_maybe_redirect_for_registration]
set page_title "Upload Absences CSV"
set context_bar [im_context_bar [list "/intranet-timesheet2/absences/" "Absences"] $page_title]

set add_absences_for_group_p [im_permission $user_id "add_absences_for_group"]

if {!$add_absences_for_group_p} {
    ad_return_complaint 1 "You have insufficient privileges to use this page"
    return
}

set page_body "
<form enctype=multipart/form-data method=POST action=upload-datev-entitlement-2.tcl>
[export_form_vars return_url]
                    <table border=0>
                      <tr> 
                        <td align=right>Filename: </td>
                        <td> 
                          <input type=file name=upload_file size=30>
                          [im_gif help "Use the &quot;Browse...&quot; button to locate your file, then click &quot;Open&quot;."]
                        </td>
                      </tr>
                      <tr> 
                        <td></td>
                        <td> 
                          <input type=submit value=Submit and Upload>
                        </td>
                      </tr>
                    </table>
</form>
"


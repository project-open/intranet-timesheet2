# /packages/intranet-translation/www/index.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/ for licensing details.

ad_page_contract {
    Show a timeline of the activities of a selected group of users.
    @author frank.bergmann@project-open.com
} {

}

set user_id [ad_maybe_redirect_for_registration]
set user_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
if {!$user_admin_p} {
    ad_return_complaint 1 "<li>You have insufficient privileges to see this page"
    return
}


set absences_sql "
	select
		im_name_from_user_id(u.user_id) as user_name,
		ua.absence_name as name,
		ua.start_date::date,
		ua.end_date::date
	from
		users u,
		im_user_absences ua
	where
		u.user_id = ua.owner_id and
		ua.end_date >= now()::date
	order by
		user_name, absence_name
"



set absences_html [im_ad_hoc_query -format html $absences_sql]

# 	(select im_day_enumerator as day from im_day_enumerator(now()::date-30, now()::date+30)) d



doc_return 200 "text/html" "
$absences_html


"





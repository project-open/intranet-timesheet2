# /packages/intranet-timesheet2/www/absences/vacation-balance-report-update-balance.tcl
#
# Copyright (C) 2003-2020 ]project-open[
#
# All rights reserved. Please check
# https://www.project-open.com/license/ for details.

ad_page_contract {
    Update the vacation balance
    @param return_url the url to return to
    @author frank.bergmann@project-open.com
} {
    vacation_balance:array
    vacation_balance_year:array
    return_url
}

set user_id [auth::require_login]
set action_forbidden_msg [lang::message::lookup "" intranet-timesheet2.Action_Forbidden "<b>Unable to execute action</b>:<br>You don't have the permissions to execute this script."]

if {![im_permission $user_id "view_hr"]} {
    ad_return_complaint 1 $action_forbidden_msg
    ad_script_abort
}


foreach uid [array names vacation_balance] {

    set new_vacation_balance $vacation_balance($uid)
    set new_vacation_balance_year $vacation_balance_year($uid)

    # Write Audit Trail before update, just in case
    im_audit -object_id $uid -action before_update

    # Backup the old value, just in case...
    db_dml backup_old_balance "
	update im_employees set
		vacation_balance_backup_previous_year = vacation_balance
	where employee_id = :uid
    "

    # Update the value and the date of the value
    db_dml update_balance "
	update im_employees set
		vacation_balance = :new_vacation_balance,
		vacation_balance_year = :new_vacation_balance_year::date
	where employee_id = :uid
    "

    # Write Audit Trail after the update
    im_audit -object_id $uid -action after_update

}


ad_returnredirect $return_url

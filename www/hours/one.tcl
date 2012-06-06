# /packages/intranet-timesheet2/www/hours/one.tcl
#
# Copyright (C) 2003-2007 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    Edit an existing timesheet element to allow an Admin to assign
    the hours to a different project.

    @author frank.bergmann@project-open.com
} {
    julian_date:integer
    user_id:integer
    project_id:integer
    { hours:float "" }
    { old_project_id:integer "" }
    return_url
    { form_mode "edit" }
    { __new_p "0"}
}


# ------------------------------------------------------------------
# Default & Security
# ------------------------------------------------------------------

set current_user_id [ad_maybe_redirect_for_registration]
if {![im_permission $current_user_id "add_hours_all"]} {
    ad_return_complaint 1 "You have insufficient privileges to use this page"
    return
}

set page_title [lang::message::lookup "" intranet-timesheet2.Reassign_logged_hours "Reassign logged hours"]
set context $page_title

if {"" == $old_project_id} { set old_project_id $project_id }

# ------------------------------------------------------------------
# Build the form
# ------------------------------------------------------------------

# Project Options including type "Task"
set project_options [im_project_options \
			 -exclude_subprojects_p 0 \
			 -exclude_tasks_p 0 \
			 -exclude_status_id [im_project_status_closed] \
			 -project_id $project_id \
]

set user_options [db_list_of_lists user_options "
	select	im_name_from_user_id(user_id) as name,
		user_id
	from	users_active
	order by name
"]


ad_form \
    -name hours \
    -cancel_url $return_url \
    -export {julian_date old_project_id return_url} \
    -form {
	{user_id:integer(select) {mode display} {label #intranet-core.User#} {options $user_options} }
	{day_date:text(text) {mode display} {label #intranet-core.Date#} }
	{project_id:integer(select) {label #intranet-core.Project#} {options $project_options} }
	{hours:float(text) {label #intranet-timesheet2.Hours#} }
	{note:text(textarea),optional,nospell {label #intranet-core.Description#} {html {rows 5 cols 60}}}
    }

ad_form -extend -name hours -on_request {

    db_1row hours_select "
	select	h.*,
		day::date as day_date
	from	im_hours h
	where	h.day::date = to_date(:julian_date, 'J')
		and h.user_id = :user_id
		and h.project_id = :project_id
    "

} -after_submit {

    if {[catch {
      db_dml hours_update "
	update	im_hours set
		project_id = :project_id,
		hours = :hours,
		note = :note
	where
		project_id = :old_project_id
		and user_id = :user_id
		and day::date = to_date(:julian_date, 'J')
      "
    } errmsg]} {
	ad_return_complaint 1 "
	    <b>Error updating timesheet information</b>:<p>
	    This error is probably due to the fact that there is already a 
	    timesheet entry for this user and this date for the given
	    project.<p>
	    Below the details of the error for reference:<p>
	    <pre>$errmsg</pre>
	"
    }

    ad_returnredirect $return_url
    ad_script_abort
}


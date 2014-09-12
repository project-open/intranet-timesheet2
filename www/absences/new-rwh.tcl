# /packages/intranet-timesheet2/www/absences/new-rwh.tcl
#
# Copyright (c) 2014 cognovís GmbH
#

ad_page_contract {
    @author malte.sussdorff@cognovis.de
} {
	{ return_url "" }
    { absence_type_id "[im_user_absence_type_rwh]"}
    { user_id_from_search ""}
}

# SET THE CORRECT ABSENCE TYPE_ID

# ------------------------------------------------------------------
# Default & Security
# ------------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set action_url "/intranet-timesheet2/absences/new-rwh"
set cancel_url "/intranet-timesheet2/absences/index"
set current_url [im_url_with_query]
set date_format "YYYY MM DD"
set form_id "weekday-absence"
set absence_type [im_category_from_id $absence_type_id]
set page_title [lang::message::lookup "" intranet-timesheet2.New_Absence_Type "%absence_type%"]
set context [list $page_title]
set read [im_permission $user_id "read_absences_all"]
set write [im_permission $user_id "add_absences_all"]

# ------------------------------------------------------------------
# Build the form
# ------------------------------------------------------------------

set weekday_options [list]
set ctr 0
foreach day [lc_get day] {
    lappend weekday_options [list $day $ctr]
    incr ctr
}

ad_form \
-name $form_id \
-cancel_url $cancel_url \
-has_edit 1 

ad_form -extend -name $form_id -form {
    {owner_id:text(select)  {label "[_ intranet-core.Employee]"} {options [im_employee_options]}}
	{absence_name:text(text) {label "[_ intranet-timesheet2.Absence_Name]"} {html {size 40}}}
	{absence_type_id:text(hidden) {label "[_ intranet-timesheet2.Type]"}}
	{start_date:date(date) {label "[_ intranet-timesheet2.Start_Date]"} {after_html {<input type="button" style="height:23px; width:23px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendarWithDateWidget('start_date', 'y-m-d');" >}}}
	{end_date:date(date) {label "[_ intranet-timesheet2.End_Date]"} {after_html {<input type="button" style="height:23px; width:23px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendarWithDateWidget('end_date', 'y-m-d');" >}}}
    {description:text(textarea),optional {label "[_ intranet-timesheet2.Description]"} {html {cols 40}}}
    {week_day_list:text(checkbox),multiple,optional {label "[_ intranet-timesheet2.Weekday]"} {options $weekday_options}}
}

ad_form -extend -name $form_id -on_request {
    # Populate elements from local variables
    if {![info exists start_date]} { set start_date [db_string today "select to_char(now(), :date_format)"] }
    if {![info exists end_date]} { set end_date [db_string today "select to_char(now(), :date_format)"] }
    if {![info exists owner_id]} {set owner_id $user_id_from_search }
} -on_submit {
    
    # Delete all vacations of that type for the user between this period.
    # Update the vacation status to cancelled
    set affected_absence_ids [im_absence_dates -start_date "[join [template::util::date get_property linear_date_no_time $start_date] "-"]"  -end_date  "[join [template::util::date get_property linear_date_no_time $end_date] "-"]"  -owner_id $owner_id -absence_type_ids $absence_type_id -type absence_ids]
    ns_log Notice "Deleting absences :: $affected_absence_ids"

    foreach absence_id $affected_absence_ids {
        db_dml cancel_absence "update im_user_absences set absence_status_id = [im_user_absence_status_deleted] where absence_id = :absence_id"
    }
        

    if {"" != $week_day_list} {

        # Get a list of days in the period which would be off for the user
        set absence_days [im_absence_week_days  -start_date "[join [template::util::date get_property linear_date_no_time $start_date] "-"]"  -end_date  "[join [template::util::date get_property linear_date_no_time $end_date] "-"]" -week_day_list $week_day_list]
    
        set weekday_absence_ids [list]
        foreach absence_date $absence_days {    
        
            # Find out if we already have an absence on that date of that type
            set absence_id [db_string absence "select absence_id from im_user_absences where absence_type_id = :absence_type_id and start_date = :absence_date and owner_id = :owner_id limit 1" -default ""]
        
            if {"" == $absence_id} {
              	lappend weekday_absence_ids [db_string new_absence "
                SELECT im_user_absence__new(
                :absence_id,
                'im_user_absence',
                now(),
                :user_id,
                '[ns_conn peeraddr]',
                null,
                :absence_name,
                :owner_id,
                :absence_date,
                :absence_date,                
                [im_user_absence_status_active],
                :absence_type_id,
                :description,
                ''
                )
         	"]
         	} else {
             	db_dml update_absence "update im_user_absences set absence_status_id = [im_user_absence_status_active] where absence_id = :absence_id"
         	  lappend weekday_absence_ids $absence_id
         	  
             	ns_log Notice "Updating absence $absence_id"
         	}
         }
    } else {
        set weekday_absence_ids ""
    }
        
    # Calculate the absence days new for the user
    set affected_absence_ids [im_absence_dates -start_date "[join [template::util::date get_property linear_date_no_time $start_date] "-"]"  -end_date  "[join [template::util::date get_property linear_date_no_time $end_date] "-"]" -ignore_absence_ids $weekday_absence_ids -type absence_ids]
    
    foreach affected_absence_id $affected_absence_ids {        
        im_absence_calculate_absence_days -absence_id $affected_absence_id
    }
    
} -after_submit {

    ad_returnredirect [export_vars -base "/intranet-timesheet2/absences/index" -url {{user_selection $owner_id} {timescale all} {absence_type_id $absence_type_id}}]
    ad_script_abort
}
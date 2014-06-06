ad_library {

    Initialization for intranet-timesheet2 module
    
    @author Frank Bergmann (frank.bergmann@project-open.com)
    @creation-date 16 November, 2006
    @cvs-id $Id$

}

# Initialize the search "semaphore" to 0.
# There should be only one thread indexing files at a time...
nsv_set intranet_timesheet2 timesheet_synchronizer_p 0

# Check for imports of external im_hours entries every every X minutes
ad_schedule_proc -thread t [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter SyncHoursInterval -default 59 ] im_timesheet2_sync_timesheet_costs

ad_schedule_proc -thread t -schedule_proc ns_schedule_weekly im_absence_update_duration_days

# Callbacks 
ad_proc -public -callback absence_on_change {
    {-absence_id:required}
    {-absence_type_id:required}
    {-user_id:required}
    {-start_date:required}
    {-end_date:required}
    {-duration_days:required}
    {-transaction_type:required}
} {
    Callback to be executed after an absence has been created
} -

# Schedule the reminders
set remind_employees_p [db_string select_parameter {
    SELECT attr_value FROM apm_parameter_values WHERE parameter_id = (
        SELECT parameter_id FROM apm_parameters WHERE package_key = 'intranet-timesheet2' AND parameter_name = 'RemindEmployeesToLogHoursP'
	);
} -default 0]

if {$remind_employees_p} {
    ad_schedule_proc -thread t -schedule_proc ns_schedule_weekly [list 1 7 0] im_timesheet_remind_employees
}


ad_proc -public -callback im_user_absence_on_submit {
    -form_id:required
    -object_id:required
} {
    This callback allows for additional validations using error_field and error_message upvar variables

    @param object_id ID of the $object_type
} -

ad_proc -public -callback im_user_absence_new_button_pressed {
    {-button_pressed:required}
} {
    This callback is executed after we checked the pressed buttons but before the normal delete / cancel check is executed. 
    
    This allows you to add additional activities based on the actions defined e.g. in the im_user_absence_new_actions. As it is called before delete / cancel you can
    have more actions defined.

} - 


ad_proc -public -callback im_user_absence_new_actions {
} {
    This callback is executed after we build the actions for the new absence form
    
    This allows you to extend in the uplevel the form with any additional actions you might want to add.

} - 

ad_proc -public -callback im_user_absence_perm_check {
    {-absence_id:required}
} {
    This callback is executed first time we determine that we have an absence_id
    
    This allows you to add additional permission checks, especially against ID guessing.

} - 



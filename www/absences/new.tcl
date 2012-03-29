# /packages/intranet-timesheet2/www/absences/new.tcl
#
# Copyright (c) 2003-2007 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.


# Skip if this page is called as part of a Workflow panel
if {![info exists panel_p]} {
    ad_page_contract {
	@param form_mode edit or display
	@author frank.bergmann@project-open.com
    } {
	absence_id:integer,optional
	{ return_url "" }
	edit_p:optional
	message:optional
	{ absence_type_id:integer 0 }
	{ form_mode "edit" }
	{ user_id_from_search "" }
    }
}


if {![info exists enable_master_p]} { set enable_master_p 1}

# ------------------------------------------------------------------
# Default & Security
# ------------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set current_user_id $user_id
set action_url "/intranet-timesheet2/absences/new"
set cancel_url "/intranet-timesheet2/absences/index"
set current_url [im_url_with_query]
if {"" == $return_url} { set return_url "/intranet-timesheet2/absences/index" }

set focus "absence.var_name"
set date_format "YYYY-MM-DD"
set date_time_format "YYYY MM DD"
set absence_type "Absence"

if {[info exists absence_id]} { 

    # absence_owner_id determines the list of projects per absence and other DynField widgets
    # it defaults to user_id when creating a new absence
    set absence_owner_id [db_string absence_owner "select owner_id from im_user_absences where absence_id = :absence_id" -default ""]

    set old_absence_type_id [db_string type "select absence_type_id from im_user_absences where absence_id = :absence_id" -default 0]
    if {0 != $old_absence_type_id} { set absence_type_id $old_absence_type_id }
    set absence_type [im_category_from_id $absence_type_id]

    if {![ad_form_new_p -key absence_id]} {
	set absence_exists_p [db_string count "select count(*) from im_user_absences where absence_id=:absence_id"]
	if {!$absence_exists_p} {
	    ad_return_complaint 1 "<b>Error: The selected absence (#$absence_id) does not exist</b>:<br>The absence has probably been deleted by its owner recently."
	    ad_script_abort
	}
    }
}

if {![exists_and_not_null absence_owner_id]} { set absence_owner_id $user_id_from_search }
if {![exists_and_not_null absence_owner_id]} { set absence_owner_id $current_user_id }

if {![info exists absence_id]} {
    set page_title [lang::message::lookup "" intranet-timesheet2.New_Absence_Type "%absence_type%"]
} else {
    set page_title [lang::message::lookup "" intranet-timesheet2.Absence_absence_type "%absence_type%"]
}

if {[exists_and_not_null user_id_from_search]} {
    set user_from_search_name [db_string name "select im_name_from_user_id(:user_id_from_search)" -default ""]
    append page_title [lang::message::lookup "" intranet-timesheet2.for_username " for %user_from_search_name%"]
}

set context [list $page_title]

set read [im_permission $current_user_id "read_absences_all"]
set write [im_permission $current_user_id "add_absences"]
set add_absences_for_group_p [im_permission $current_user_id "add_absences_for_group"]

if {[info exists absence_id]} {
    im_absence_permissions $current_user_id $absence_id view read write admin
}
if {![im_permission $current_user_id "add_absences"]} {
    ad_return_complaint "[_ intranet-timesheet2.lt_Insufficient_Privileg]" "
    <li>[_ intranet-timesheet2.lt_You_dont_have_suffici]"
}


# Redirect if the type of the object hasn't been defined and
# if there are DynFields specific for subtypes.
if {0 == $absence_type_id && ![info exists absence_id]} {
    set all_same_p [im_dynfield::subtype_have_same_attributes_p -object_type "im_user_absence"]
    set all_same_p 0
    if {!$all_same_p} {
	ad_returnredirect [export_vars -base "/intranet/biz-object-type-select" { user_id_from_search {object_type "im_user_absence"} {return_url $current_url} {type_id_var "absence_type_id"} }]
    }
}

# ------------------------------------------------------------------
# Action permissions
# ------------------------------------------------------------------

set actions [list]

# Check whether to show the "Edit" and "Delete" buttons.
# These buttons only make sense if the absences already exists.
#
if {[info exists absence_id]} {
    set absence_exists_p [db_string abs_ex "select count(*) from im_user_absences where absence_id = :absence_id"]
    if {$absence_exists_p} {

	set edit_perm_func [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter AbsenceNewPageWfEditButtonPerm -default "im_absence_new_page_wf_perm_edit_button"]
	set delete_perm_func [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter AbsenceNewPageWfDeleteButtonPerm -default "im_absence_new_page_wf_perm_delete_button"]

	if {[eval [list $edit_perm_func -absence_id $absence_id]]} {
	    lappend actions [list [lang::message::lookup {} intranet-timesheet2.Edit Edit] edit]
	}
	if {[eval [list $delete_perm_func -absence_id $absence_id]]} {
	    lappend actions [list [lang::message::lookup {} intranet-timesheet2.Delete Delete] delete]

	}
    }
}

# ------------------------------------------------------------------
# Delete pressed?
# ------------------------------------------------------------------

set button_pressed [template::form get_action absence]
if {"delete" == $button_pressed} {
	db_transaction {
		callback absence_on_change \
			-absence_id $absence_id \
			-absence_type_id "" \
			-user_id "" \
			-start_date "" \
			-end_date "" \
			-duration_days "" \
			-transaction_type "remove"

		db_dml del_tokens "delete from wf_tokens where case_id in (select case_id from wf_cases where object_id = :absence_id)"
		db_dml del_case "delete from wf_cases where object_id = :absence_id"
		db_string absence_delete "select im_user_absence__delete(:absence_id)"
		ad_returnredirect $cancel_url
	} on_error {
            ad_return_error "Error deleting absence" "<br>Error:<br>$errmsg<br><br>"
            return
	}
}

# ------------------------------------------------------------------
# Build the form
# ------------------------------------------------------------------

set form_fields {
	absence_id:key
	{absence_owner_id:text(hidden),optional}
	{absence_name:text(text) {label "[_ intranet-timesheet2.Absence_Name]"} {html {size 40}}}
	{absence_type_id:text(im_category_tree) {label "[_ intranet-timesheet2.Type]"} {custom {category_type "Intranet Absence Type"}}}
}

if {$add_absences_for_group_p} {

    set group_options [im_profile::profile_options_all -translate_p 1]
    set group_options [linsert $group_options 0 [list "" ""]]

    lappend form_fields	{group_id:text(select),optional {label "[lang::message::lookup {} intranet-timesheet2.Valid_for_Group {Valid for Group}]"} {options $group_options}}

} else {
    # The user doesn't have the right to specify absences for groups - set group_id to NULL
    set group_id ""
}

ad_form \
    -name absence \
    -cancel_url $cancel_url \
    -action $action_url \
    -actions $actions \
    -has_edit 1 \
    -mode $form_mode \
    -export {user_id return_url} \
    -form $form_fields

if {[im_permission $current_user_id edit_absence_status]} {
    set form_list {{absence_status_id:text(im_category_tree) {label "[lang::message::lookup {} intranet-timesheet2.Status Status]"} {custom {category_type "Intranet Absence Status"}}}}
} else {
#    set form_list {{absence_status_id:text(im_category_tree) {mode display} {label "[lang::message::lookup {} intranet-timesheet2.Status Status]"} {custom {category_type "Intranet Absence Status"}}}}
    set form_list {{absence_status_id:text(hidden)}}
}
ad_form -extend -name absence -form $form_list

ad_form -extend -name absence -form {
    {start_date:date(date) {label "[_ intranet-timesheet2.Start_Date]"} {format "YYYY-MM-DD"} {after_html {<input type="button" style="height:23px; width:23px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendarWithDateWidget('start_date', 'y-m-d');" >}}}
    {end_date:date(date) {label "[_ intranet-timesheet2.End_Date]"} {format "YYYY-MM-DD"} {after_html {<input type="button" style="height:23px; width:23px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendarWithDateWidget('end_date', 'y-m-d');" >}}}
    {duration_days:float(text) {label "[lang::message::lookup {} intranet-timesheet2.Duration_days {Duration (Days)}]"} {help_text "[lang::message::lookup {} intranet-timesheet2.Duration_days_help {Please specify the absence duration as a number or fraction of days. Example: '1'=one day, '0.5'=half a day)}]"}}
    {description:text(textarea),optional {label "[_ intranet-timesheet2.Description]"} {html {cols 40}}}
    {contact_info:text(textarea),optional {label "[_ intranet-timesheet2.Contact_Info]"} {html {cols 40}}}
}


# ------------------------------------------------------------------
# Add DynFields
# ------------------------------------------------------------------

set my_absence_id 0
if {[info exists absence_id]} { set my_absence_id $absence_id }

set field_cnt [im_dynfield::append_attributes_to_form \
    -object_subtype_id $absence_type_id \
    -object_type "im_user_absence" \
    -form_id absence \
    -object_id $my_absence_id \
    -form_display_mode $form_mode \
]


# ------------------------------------------------------------------
# Form Actions
# ------------------------------------------------------------------

ad_form -extend -name absence -on_request {

    # Populate elements from local variables
    if {![info exists start_date]} { set start_date [db_string today "select to_char(now(), :date_time_format)"] }
    if {![info exists end_date]} { set end_date [db_string today "select to_char(now(), :date_time_format)"] }
    if {![info exists duration_days]} { set duration_days "" }
    if {![info exists absence_owner_id] || 0 == $absence_owner_id} { set absence_owner_id $user_id_from_scratch }
    if {![info exists absence_owner_id] || 0 == $absence_owner_id} { set absence_owner_id $current_user_id }
    if {![info exists absence_type_id]} { set absence_type_id [im_absence_type_vacation] }
    if {![info exists absence_status_id]} { set absence_status_id [im_absence_status_requested] }
    
} -select_query {

	select	a.*,
		a.owner_id as absence_owner_id
	from	im_user_absences a
	where	absence_id = :absence_id


} -validate {

    {duration_days
	{$duration_days > 0}
	"Positive number expected"
    }
    
} -new_data {

    set start_date_sql [template::util::date get_property sql_timestamp $start_date]
    set end_date_sql [template::util::date get_property sql_timestamp $end_date]

    # Check the date range

    set date_range_error_p [db_string date_range "select $end_date_sql >= $start_date_sql"]
    if {"f" == $date_range_error_p} {
	ad_return_complaint 1 "<b>Date Range Error</b>:<br>Please revise your start and end date."
	ad_script_abort
    }

    # Check the number of absence days per interval
    set date_range_days [db_string date_range "select date($end_date_sql) - date($start_date_sql) + 1"]
    if {$duration_days > [expr $date_range_days+1]} {
	ad_return_complaint 1 "<b>Date Range Error</b>:<br>Duration is longer then date interval."
	ad_script_abort
    }

    if { [db_string exists "
		select	count(*) 
		from	im_user_absences a
		where	a.owner_id = :absence_owner_id and
			a.absence_type_id = :absence_type_id and
			a.start_date = $start_date_sql
	   "]
     } {
	ad_return_complaint 1 [lang::message::lookup "" intranet-timesheet2.Absence_Duplicate_Start "There is already an absence with exactly the same owner, type and start date."]
    }

    db_transaction {
	set absence_id [db_string new_absence "
		SELECT im_user_absence__new(
			:absence_id,
			'im_user_absence',
			now(),
			:user_id,
			'[ns_conn peeraddr]',
			null,

			:absence_name,
			:absence_owner_id,
			$start_date_sql,
			$end_date_sql,

			:absence_status_id,
			:absence_type_id,
			:description,
			:contact_info
		)
	"]

	db_dml update_absence "
		update im_user_absences	set
			duration_days = :duration_days,
			group_id = :group_id
		where absence_id = :absence_id
	"

	db_dml update_object "
		update acs_objects set
			last_modified = now()
		where object_id = :absence_id
	"

	im_dynfield::attribute_store \
	    -object_type "im_user_absence" \
	    -object_id $absence_id \
	    -form_id absence

	set wf_key [db_string wf "select trim(aux_string1) from im_categories where category_id = :absence_type_id" -default ""]
	set wf_exists_p [db_string wf_exists "select count(*) from wf_workflows where workflow_key = :wf_key"]
	if {$wf_exists_p} {
	    set context_key ""
	    set case_id [wf_case_new \
			     $wf_key \
			     $context_key \
			     $absence_id
			]

	    # Determine the first task in the case to be executed and start+finisch the task.
            im_workflow_skip_first_transition -case_id $case_id
	}
	
	# Callback 
    ns_log NOTICE "Callback: Calling callback 'absence_on_change' "

	callback absence_on_change \
	    -absence_id $absence_id \
	    -absence_type_id $absence_type_id \
	    -user_id $absence_owner_id \
	    -start_date $start_date_sql \
	    -end_date $end_date_sql \
	    -duration_days $duration_days \
	    -transaction_type "add"

	# Audit the action
	im_audit -object_type im_user_absence -action after_create -object_id $absence_id -status_id $absence_status_id -type_id $absence_type_id
    }

} -edit_data {

    set start_date_sql [template::util::date get_property sql_timestamp $start_date]
    set end_date_sql [template::util::date get_property sql_timestamp $end_date]

    # Check the date range
    set date_range_error_p [db_string date_range "select $end_date_sql >= $start_date_sql"]
    if {"f" == $date_range_error_p} {
	ad_return_complaint 1 "<b>Date Range Error</b>:<br>Please revise your start and end date."
	ad_script_abort
    }

    # Check the number of absence days per interval
    set date_range_days [db_string date_range "select date($end_date_sql) - date($start_date_sql) + 1"]
    if {$duration_days > $date_range_days} {
	ad_return_complaint 1 "<b>Date Range Error</b>:<br>Duration is longer then date interval."
	ad_script_abort
    }

    db_dml update_absence "
		UPDATE im_user_absences SET
			absence_name = :absence_name,
			owner_id = :absence_owner_id,
			start_date = $start_date_sql,
			end_date = $end_date_sql,
			duration_days = :duration_days,
			group_id = :group_id,
			absence_status_id = :absence_status_id,
			absence_type_id = :absence_type_id,
			description = :description,
			contact_info = :contact_info
		WHERE
			absence_id = :absence_id
    "

    im_dynfield::attribute_store \
        -object_type "im_user_absence" \
        -object_id $absence_id \
        -form_id absence


    # Audit the action
    im_audit -object_type im_user_absence -action after_update -object_id $absence_id -status_id $absence_status_id -type_id $absence_type_id


} -after_submit {

    ad_returnredirect $return_url
    ad_script_abort
}


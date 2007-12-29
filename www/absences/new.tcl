# /packages/intranet-timesheet2/www/absences/new.tcl
#
# Copyright (c) 2003-2007 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    @param form_mode edit or display
    @author frank.bergmann@project-open.com
} {
    absence_id:integer,optional
    { return_url "" }
    edit_p:optional
    message:optional
    { form_mode "edit" }
}


# ------------------------------------------------------------------
# Default & Security
# ------------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]

set action_url "/intranet-timesheet2/absences/new"
set cancel_url "/intranet-timesheet2/absences/index"
if {"" == $return_url} { set return_url "/intranet-timesheet2/absences/index" }

set focus "absence.var_name"
set date_format "YYYY-MM-DD-HH24"
set date_time_format "YYYY MM DD HH24 MI SS"

set page_title [_ intranet-timesheet2.New_Absence]
set context [list $page_title]

set read [im_permission $user_id "read_absences_all"]
set write [im_permission $user_id "add_absences"]
if {[info exists absence_id]} {
    im_absence_permissions $user_id $absence_id view read write admin
}

#!!! Check permission
if {![im_permission $user_id "add_absences"]} {
    ad_return_complaint "[_ intranet-timesheet2.lt_Insufficient_Privileg]" "
    <li>[_ intranet-timesheet2.lt_You_dont_have_suffici]"
}



# ------------------------------------------------------------------
# Delete pressed?
# ------------------------------------------------------------------

set actions [list {"Edit" edit} ]
if {[im_permission $user_id add_absences]} {
    lappend actions {"Delete" delete}
}

set button_pressed [template::form get_action absence]
if {"delete" == $button_pressed} {
    db_string absence_delete "select im_user_absence__delete(:absence_id)"
    ad_returnredirect $cancel_url
}

# ------------------------------------------------------------------
# Build the form
# ------------------------------------------------------------------

ad_form \
    -name absence \
    -cancel_url $cancel_url \
    -action $action_url \
    -actions $actions \
    -mode $form_mode \
    -export {user_id return_url} \
    -form {
	absence_id:key
	{owner_id:text(hidden)}
	{absence_name:text(text) {label "[_ intranet-timesheet2.Name]"} {html {size 40}}}
	{absence_type_id:text(im_category_tree) {label "[_ intranet-timesheet2.Type]"} {custom {category_type "Intranet Absence Type"}}}
	{absence_status_id:text(im_category_tree) {label "[_ intranet-timesheet2.Status]"} {custom {category_type "Intranet Absence Status"}}}

	{start_date:date(date),optional {label "[_ intranet-timesheet2.Start_Date]"} {format "DD Month YYYY HH24:MI"}}
	{end_date:date(date),optional {label "[_ intranet-timesheet2.End_Date]"} {format "DD Month YYYY HH24:MI"}}
	{description:text(textarea),optional {label "[_ intranet-timesheet2.Description]"} {html {cols 40}}}
	{contact_info:text(textarea),optional {label "[_ intranet-timesheet2.Contact_Info]"} {html {cols 40}}}
    }


# Add the right dynfields for the given type
set absence_type_id 0
if {[info exists absence_id]} {
    set absence_type_id [db_string ptype "select absence_type_id from im_user_absences where absence_id = :absence_id" -default 0]
}
set my_absence_id 0
if {[info exists absence_id]} { set my_absence_id $absence_id }
set field_cnt [im_dynfield::append_attributes_to_form \
    -object_subtype_id $absence_type_id \
    -object_type "im_user_absence" \
    -form_id absence \
    -object_id $my_absence_id \
    -form_display_mode $form_mode \

]


ad_form -extend -name absence -on_request {

    # Populate elements from local variables
    if {![info exists start_date]} { set start_date [db_string today "select to_char(now(), :date_time_format)"] }
    if {![info exists end_date]} { set end_date [db_string today "select to_char(now()+'24 hours'::interval, :date_time_format)"] }
    if {![info exists owner_id]} { set owner_id $user_id }
    if {![info exists absence_type_id]} { set absence_type_id [im_absence_type_vacation] }
    if {![info exists absence_status_id]} { set absence_status_id [im_absence_status_requested] }
    
} -select_query {
	select	a.*,
		to_char(start_date, 'YYYY MM DD HH24 MI') as start_date,
		to_char(end_date, 'YYYY MM DD HH24 MI') as end_date
	from	im_user_absences a
	where	absence_id = :absence_id
} -new_data {

    set start_date_sql [template::util::date get_property sql_timestamp $start_date]
    set end_date_sql [template::util::date get_property sql_timestamp $end_date]

    if { [db_string exists "
		select	count(*) 
		from	im_user_absences
		where	start_date = to_timestamp(:start_date, 'YYYY MM DD HH24 MI')
	   "]
     } {
	ad_return_complaint 1 [lang::message::lookup {} intranet-timesheet2.Absence_Duplicate_Start {There is already an absence with exactly the same start date.}]
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
			:owner_id,
			$start_date_sql,
			$end_date_sql,
			:absence_status_id,
			:absence_type_id,
			:description,
			:contact_info
		)
	"]

	im_dynfield::attribute_store \
	    -object_type "im_user_absence" \
	    -object_id $absence_id \
	    -form_id absence

	set wf_key [db_string wf "select aux_string1 from im_categories where category_id = :absence_type_id" -default ""]
	set wf_exists_p [db_string wf_exists "select count(*) from wf_workflows where workflow_key = :wf_key"]
	if {$wf_exists_p} {
	    set context_key ""
	    set case_id [wf_case_new \
			     $wf_key \
			     $context_key \
			     $absence_id
			]
	}
    }

} -edit_data {

    set start_date_sql [template::util::date get_property sql_timestamp $start_date]
    set end_date_sql [template::util::date get_property sql_timestamp $end_date]

    db_dml update_absence "
		UPDATE im_user_absences SET
			absence_name = :absence_name,
			owner_id = :owner_id,
			start_date = $start_date_sql,
			end_date = $end_date_sql,
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

} -after_submit {
	ad_returnredirect $return_url
	ad_script_abort
}


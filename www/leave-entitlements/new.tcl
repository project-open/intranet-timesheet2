# /packages/intranet-timesheet2/www/leave-entitlement/new.tcl
#

ad_page_contract {
    @param form_mode edit or display
    @author malte.sussdorff@cognovis.de
} {
    {owner_id ""}
    { leave_entitlement_type_id:integer 5000 }
    { leave_entitlement_status_id:integer 16000 }
    leave_entitlement_id:integer,optional
    {return_url ""}
}


# ------------------------------------------------------------------
# Default & Security
# ------------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set current_user_id $user_id
set action_url "/intranet-timesheet2/leave-entitlement/new"
set leave_entitlement_type [im_category_from_id $leave_entitlement_type_id]

if {"" == $owner_id && ![info exists leave_entitlement_id]} {
    set owner_id $user_id
}

set owner_name [im_name_from_user_id $owner_id]
# ------------------------------------------------------------------
# Build the form
# ------------------------------------------------------------------

ad_form -name leave_entitlement -export {return_url leave_entitlement_status_id} -form {
    leave_entitlement_id:key
    owner_id:text(hidden)
    {owner_name:text(inform) {label "owner"} {value $owner_name}}
    {leave_entitlement_name:text(text) {label "[_ intranet-timesheet2.Absence_Name]"} {html {size 40}}}
    {leave_entitlement_type_id:text(im_category_tree) {label "[_ intranet-timesheet2.Type]"} {custom {category_type "Intranet Absence Type"}}}
    {booking_date:date(date) {label "[_ intranet-timesheet2.Booking_date]"} {format "YYYY-MM-DD"} {after_html {<input type="button" style="height:23px; width:23px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendarWithDateWidget('booking_date', 'y-m-d');" >}}}
    {entitlement_days:float(text) {label "[lang::message::lookup {} intranet-timesheet2.Entitlement_days {Leave Entitlement (Days)}]"} {help_text "[lang::message::lookup {} intranet-timesheet2.Entitlement_days_help {Please specify the leave entitlement as a number or fraction of days. Example: '1'=one day, '0.5'=half a day)}]"}}
    {description:text(textarea),optional {label "[_ intranet-timesheet2.Description]"} {html {cols 40}}}
}

# ------------------------------------------------------------------
# Form Actions
# ------------------------------------------------------------------

ad_form -extend -name leave_entitlement -edit_request {
    db_1row entitlement "    select	*
    from	im_user_leave_entitlements
    where   leave_entitlement_id = :leave_entitlement_id"
    set owner_name [im_name_from_user_id $owner_id]
    set owner_name "<a href=/intranet/users/view?user_id=$owner_id>$owner_name<a/>"
} -on_request {
    set booking_date [db_string now "select to_char(now(),'YYYY-MM-DD') from dual"]
} -validate {
    
} -new_data {
    set booking_date_sql [template::util::date get_property sql_timestamp $booking_date]
    db_transaction {
	set absence_id [db_string new_absence "
	    	SELECT im_user_leave_entitlement__new(
			:leave_entitlement_id,
			'im_user_leave_entitlement',
			now(),
			:user_id,
			'[ns_conn peeraddr]',
			null,

			:leave_entitlement_name,
			:owner_id,
			$booking_date_sql,
			:entitlement_days,
			:leave_entitlement_status_id,
			:leave_entitlement_type_id,
			:description
		)
	"]

	db_dml update_object "
			update acs_objects set
			last_modified = now()
		where object_id = :absence_id
		"
	
	# Audit the action
	im_audit -object_type im_user_leave_entitlement -action after_create -object_id $leave_entitlement_id -status_id $leave_entitlement_status_id -type_id $leave_entitlement_type_id
    }
} -edit_data {
    
    set booking_date_sql [template::util::date get_property sql_timestamp $booking_date]
    
    db_dml update_leave_entitlement "
    		UPDATE im_user_leave_entitlements SET
			leave_entitlement_name = :leave_entitlement_name,
			owner_id = :owner_id,
			booking_date = $booking_date_sql,
			entitlement_days = :entitlement_days,
			leave_entitlement_status_id = :leave_entitlement_status_id,
			leave_entitlement_type_id = :leave_entitlement_type_id,
			description = :description
		WHERE
			leave_entitlement_id = :leave_entitlement_id
    "
    
    # Audit the action
    im_audit -object_type im_user_leave_entitlement -action after_update -object_id $leave_entitlement_id -status_id $leave_entitlement_status_id -type_id $leave_entitlement_type_id
    
    
} -after_submit {
    if {"" == $return_url} {
	set return_url [export_vars -base "/intranet-timesheet2/leave-entitlements/new" -url {leave_entitlement_id}]
    } 
    ad_returnredirect $return_url

}

if {![info exists leave_entitlement_id]} {
    set page_title [lang::message::lookup "" intranet-timesheet2.New_Leave_Entitlement_Type "%leave_entitlement_type%"]
} else {
    set page_title [lang::message::lookup "" intranet-timesheet2.Leave_Entitlement_type "%leave_entitlement_type%"]
}

if {[exists_and_not_null owner]} {
    set user_from_search_name [db_string name "select im_name_from_user_id(:owner)" -default ""]
    append page_title [lang::message::lookup "" intranet-timesheet2.for_username " for %user_from_search_name%"]
}

set context [list $page_title]
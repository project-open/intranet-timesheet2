# packages/intranet-timesheet2/tcl/intranet-leave-entitlement-procs.tcl

## Copyright (c) 2011, cognovís GmbH, Hamburg, Germany
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see
# <http://www.gnu.org/licenses/>.
# 

ad_library {
    
    Procedures for leave entitlements
    
    @author Malte Sussdorff (malte.sussdorff@cognovis.de)
    @creation-date 2013-11-20
    @cvs-id $Id$
}

ad_proc -public im_leave_entitlement_user_component {
    -user_id:required
} {
    Returns a HTML component showing the leave entitlements
    for the user
} {
    set current_user_id [ad_get_user_id]
    # This is a sensitive field, so only allows this for the user himself
    # and for users with HR permissions.

    set read_p 0
    if {$user_id == $current_user_id} { set read_p 1 }
    if {[im_permission $current_user_id view_hr]} { set read_p 1 }
    if {!$read_p} { return "" }

    set params [list \
		    [list user_id_from_search $user_id] \
		    [list return_url [im_url_with_query]] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-timesheet2/lib/leave-entitlements"]
    return [string trim $result]
}


ad_proc -public im_leave_entitlement_absence_balance_component {
    -user_id:required
} {
    Returns a HTML component showing the balance of his entitlements and how much of it is spend
} {

    # Show only if user is an employee
    if { ![im_user_is_employee_p $user_id] } { return "" }

    set current_user_id [ad_get_user_id]
    # This is a sensitive field, so only allows this for the user himself
    # and for users with HR permissions.

    set read_p 0
    if {$user_id == $current_user_id} { set read_p 1 }
    if {[im_permission $current_user_id view_hr]} { set read_p 1 }
    if {!$read_p} { return "" }

    set params [list \
		    [list user_id $user_id] \
		    [list return_url [im_url_with_query]] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-timesheet2/lib/absence-balance-component"]

    return [string trim $result]
}


ad_proc -public im_leave_entitlement_remaining_days {
    -user_id:required
    -absence_type_id:required
    {-approved_p "0"}
    {-ignore_absence_id ""}
} {
    Returns the number of remaining days for the user of a certain absence type
} {

    if {!$approved_p} {
        set approved_sql ""
    } else {
        set approved_sql ""
    }

    set entitlement_days [db_string entitlement_days "
	select
                sum(l.entitlement_days) from im_user_leave_entitlements l where leave_entitlement_type_id = :absence_type_id and owner_id = :user_id $approved_sql" -default 0]

    set absence_days [im_absence_days -owner_id $user_id -absence_type_ids $absence_type_id -approved_p $approved_p -ignore_absence_id $ignore_absence_id]
    set remaining_days [expr $entitlement_days - $absence_days]
    return $remaining_days


}

ad_proc -public im_leave_entitlement_create_yearly_vacation {
    -year
} {
    Small Procedure to create the yearly vacation for each user if not already created
} {
    set booking_date "${year}-01-01"
    set leave_entitlement_name "Annual Leave"
    set leave_entitlement_status_id "16000"
    set leave_entitlement_type_id "5000"
    set description "Automatically generated"
    set user_id [ad_conn user_id]
    
    set employee_vacation_list [db_list_of_lists employee_vacation "select employee_id, vacation_days_per_year from im_employees 
        where employee_status_id = [im_employee_status_active]
        and vacation_days_per_year is not null
        and employee_id not in (select owner_id from im_user_leave_entitlements 
            where booking_date = :booking_date and leave_entitlement_name = :leave_entitlement_name)"]
    
    foreach employee_vacation $employee_vacation_list {
        set leave_entitlement_id [db_nextval acs_object_id_seq]
        
        set owner_id [lindex $employee_vacation 0]
        set entitlement_days [lindex $employee_vacation 1]
        
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
                :booking_date,
                :entitlement_days,
                :leave_entitlement_status_id,
                :leave_entitlement_type_id,
                :description
                )"]

            db_dml update_object "
	            update acs_objects set
			    last_modified = now()
                where object_id = :absence_id"
	
            # Audit the action
            im_audit -object_type im_user_leave_entitlement -action after_create -object_id $leave_entitlement_id -status_id $leave_entitlement_status_id -type_id $leave_entitlement_type_id
            ds_comment "Entitlement created for $owner_id with $entitlement_days"
        }
    }
}
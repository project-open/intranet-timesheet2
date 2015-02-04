# packages/intranet-timesheet2/tcl/intranet-leave-entitlement-procs.tcl

## Copyright (c) 2011, cognovis GmbH, Hamburg, Germany
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
    {-ignore_absence_ids ""}
    {-booking_date ""}
} {
    Returns the number of remaining days for the user of a certain absence type
    
    @param approved_p Only calculate based on the approved vacation days
    @param booking_date Define which leave entitlements should be included. Defaults to current date (everything earned up until today)
} {
    return [util_memoize [list im_leave_entitlement_remaining_days_helper -absence_type_id $absence_type_id -user_id $user_id -approved_p $approved_p -ignore_absence_ids $ignore_absence_ids -booking_date $booking_date] 5]
}


ad_proc -public im_leave_entitlement_remaining_days_helper {
    -user_id:required
    -absence_type_id:required
    {-approved_p "0"}
    {-ignore_absence_ids ""}
    {-booking_date ""}
    {-requested_daysVar ""}
} {
    Returns the number of remaining days for the user of a certain absence type for the year in which the absence is requested.
    
    @param approved_p Only calculate based on the approved vacation days
    @param booking_date Define which leave entitlements should be included. Defaults to current date (everything earned up until today)
} {

    if { $requested_daysVar ne {} } {
        upvar $requested_daysVar requested_days
    }

    set current_year [dt_systime -format "%Y"]
    set eoy "${current_year}-12-31"
    set soy "${current_year}-01-01"
    
    # By default calculate all entitlements from the past
    set booking_date_sql "and booking_date <= to_date(:eoy,'YYYY-MM-DD')"
    
    # Calculate against all absences in the past
    set date_sql "and start_date::date <=:eoy"
    
    if {$booking_date ne ""} {
        set booking_year [string range $booking_date 0 3]
        if {$booking_year > $current_year} {
            set eoy "${booking_year}-12-31"
            set soy "${booking_year}-01-01"

            # This is a booking for a future year
            # Only calculate entitlements for that year
            set booking_date_sql "and booking_date <= to_date(:eoy,'YYYY-MM-DD') and to_date(:soy,'YYYY-MM-DD') <= booking_date"
            set date_sql "and start_date::date <=:eoy and end_date::date >=:soy"
        }
    }
    
    
    if { $absence_type_id == [im_user_absence_type_overtime] } {
        
        # for the overtime category (and child categories) we are not 
        # filtering the leave entitlements only for the current / booking
        # year, but use all of them
        
        set booking_date_sql ""
        set date_sql ""
        
    } 
    
    set sql "
            select coalesce(sum(l.entitlement_days),0) as absence_days 
            from im_user_leave_entitlements l 
            where leave_entitlement_type_id = :absence_type_id 
            and owner_id = :user_id 
            $booking_date_sql
        "

    set entitlement_days [db_string entitlement_days $sql -default 0]    

	set absence_type [im_category_from_id $absence_type_id]
    
    # Ignore the balance for bank holidays

    set vacation_category_ids [im_sub_categories 5000]
    set exclude_category_ids [db_list categories "
    	select
                    category_id
    	from
    		im_categories c
    	where
                    category_type = 'Intranet Absence Type' and category_id not in ([template::util::tcl_to_sql_list $vacation_category_ids])
    "]

	# Check if we have a workflow and then only use the approved days
	set wf_key [db_string wf "select trim(aux_string1) from im_categories where category_id = :absence_type_id" -default ""]
	set wf_exists_p [db_string wf_exists "select count(*) from wf_workflows where workflow_key = :wf_key"]
    
    # We need to ignore this absence_id from the calculation of
    # absence days. Usually during an edit
    if {$ignore_absence_ids eq ""} {
	    set ignore_absence_sql ""
    } else {
        set ignore_absence_sql "and absence_id not in ([template::util::tcl_to_sql_list $ignore_absence_ids])"
    }
    
    set requested_days ""
    if {$wf_exists_p} {

        set absence_days [db_string absence_days "select coalesce(sum(duration_days),0)
            from im_user_absences 
            where absence_type_id = :absence_type_id
            and absence_status_id in ([template::util::tcl_to_sql_list [im_sub_categories [im_user_absence_status_active]]])
            and owner_id = :user_id
            $date_sql
            $ignore_absence_sql" -default 0]

        set requested_days [db_string requested_days "select coalesce(sum(duration_days),0) 
            from im_user_absences 
            where absence_type_id = :absence_type_id
            and absence_status_id in ([template::util::tcl_to_sql_list [im_sub_categories [im_user_absence_status_requested]]])
            and owner_id = :user_id
            $date_sql
            $ignore_absence_sql" -default 0]

        set remaining_days [expr $entitlement_days - $absence_days]
        if {!$approved_p} {
            # We need to substract the requested days as well
            set remaining_days [expr $remaining_days - $requested_days]
        }
    } else {
        set absence_days [db_string absence_days "select coalesce(sum(duration_days),0)
            from im_user_absences 
            where absence_type_id = :absence_type_id
            and absence_status_id in ([template::util::tcl_to_sql_list [im_sub_categories [im_user_absence_status_active]]])
            and owner_id = :user_id
            $date_sql
            $ignore_absence_sql" -default 0]
        set remaining_days [expr $entitlement_days - $absence_days]
    } 

    return $remaining_days
}

ad_proc -public im_leave_entitlement_create_yearly_vacation {
    -year
} {
    Small Procedure to create the yearly vacation for each user if not already created
} {
    set booking_date "${year}-01-01"
    set leave_entitlement_name "Annual Leave"
    set leave_entitlement_status_id "[im_user_absence_status_active]"
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
        }
    }
}

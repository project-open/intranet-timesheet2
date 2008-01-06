# /packages/intranet-core/www/admin/categories/category-add-2.tcl
#
# Copyright (C) 1998-2004 various parties
# The code is based on ArsDigita ACS 3.4
#
# This program is free software. You can redistribute it
# and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation;
# either version 2 of the License, or (at your option)
# any later version. This program is distributed in the
# hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.

ad_page_contract {

    Save (changes) in absence.

    @param absence_id    ID of plugin to change
    @param user_id       Conserned user
    @param start_date    Absence start
    @param end_date      Absence end
    @param description   Description of absence
    @param contact_info  Contact information
    @param return_url    url to be send back after the saving
    @param absence_type_id  the type of this absence
    @param submit        the type of submission (can be Delete)

    @author mai-bee@gmx.net
} {
    {absence_id:integer 0}
    {absence_name ""}
    owner_id:notnull
    start_date:notnull
    end_date:notnull
    description:notnull
    contact_info:notnull
    absence_type_id:integer
    { absence_status_id:integer 16004}
    { submit_save "" }
    { submit_del "" }
}


# ---------------------------------------------------------------
# Permission
# ---------------------------------------------------------------

set current_user_id [ad_maybe_redirect_for_registration]

if {![im_permission $current_user_id "add_absences"]} {
    ad_return_complaint "[_ intranet-timesheet2.lt_Insufficient_Privileg]" "
    <li>[_ intranet-timesheet2.lt_You_dont_have_suffici]"
}



# ---------------------------------------------------------------
# 
# ---------------------------------------------------------------

set exception_count 0
set exception_text ""

# Check that Start & End-Date have correct format
if {![regexp {^[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]$} $start_date]} {
    ad_return_complaint 1 "Start Date doesn't have the right format.<br>
    Current value: '$start_date'<br>
    Expected format: 'YYYY-MM-DD'"
}

if {![regexp {^[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]$} $end_date]} {
    ad_return_complaint 1 "End Date doesn't have the right format.<br>
    Current value: '$end_date'<br>
    Expected format: 'YYYY-MM-DD'"
}


if {"" == $absence_name} { set absence_name $description }

set absence_objectified_p [db_string ofied {select count(*) from acs_object_types where object_type = 'im_user_absence'}]


regexp {[0-9]*-[0-9]*-[0-9]*} $start_date start_date_int
regexp {[0-9]*-[0-9]*-[0-9]*} $end_date end_date_int

if { $end_date_int < $start_date_int } {
    incr exception_count
    append exception_text "<li>The End Date must be the same day or later then the Start Date"
}

if { $exception_count > 0 } {
    ad_return_complaint $exception_count $exception_text 
    return
}

if {"" != $submit_del} {

    if {$absence_id > 0} {
	if [catch {
	    db_dml delete_absence "DELETE from im_user_absences where absence_id = :absence_id"
	} errmsg ] {
	    ad_return_complaint "Argument Error" "<ul>$errmsg</ul>"
	}
    }
}

if {"" != $submit_save} {
    
    set exists [db_string absence_exists "
	select count(*) 
	from im_user_absences 
	where absence_id = :absence_id
    "]

    if {!$exists} {

	if [catch {
	    db_dml insert_absence "
			INSERT INTO im_user_absences (
				absence_id, 
				owner_id, 
				start_date, 
				end_date, 
				description, 
				contact_info, 
				absence_type_id
			) values (
				:absence_id,
				:owner_id, 
				:start_date, 
				:end_date, 
				:description, 
				:contact_info, 
				:absence_type_id
	    )"
	} errmsg] {
	    ad_return_complaint "Argument Error" " <pre>$errmsg</pre>"
	}


	if {$absence_objectified_p} {
	    db_string ofied "
		SELECT acs_object__new(
			:absence_id,
			'im_user_absence',
			now(),
			:current_user_id,
			'[ns_conn peeraddr]',
			null,
			'f'
		)
	    "
	}

	# Create a workflow
        if {$absence_objectified_p} {
	    set wf_key [db_string wf_key "
		select	aux_string1
		from	im_categories
		where	category_id = :absence_type_id
	    " -default ""]

	    if {"" != $wf_key} {


		
		# Check that the workflow_key is available
		set wf_valid_p [db_string wf_valid_check "
		        select count(*)
		        from acs_object_types
		        where object_type = :wf_key
		"]

		if {!$wf_valid_p} {
		    ad_return_complaint 1 "Workflow '$wf_key' does not exist"
		    ad_script_abort
		}

		# Launch the Workflow case
		# Context_key not used aparently...
		set context_key ""
		set case_id [wf_case_new \
		                $wf_key \
		                $context_key \
		                $absence_id
		]

		# Determine the first task in the case to be executed and start+finisch the task.
		im_workflow_skip_first_transition -case_id $case_id
	    }
	}
    }

    if [catch {
	db_dml update_absence "
			UPDATE im_user_absences SET
			        owner_id = :owner_id,
			        start_date = :start_date,
			        end_date = :end_date,
			        description = :description,
			        contact_info = :contact_info,
			        absence_type_id = :absence_type_id 
			WHERE
			        absence_id = :absence_id"
    } errmsg ] {
	ad_return_complaint "Argument Error" "<pre>$errmsg</pre>"
	return
    }
    
    if {$absence_objectified_p} {
	db_dml update_absences "
		UPDATE im_user_absences set
			absence_name = :absence_name,
			absence_status_id = :absence_status_id
		WHERE
			absence_id = :absence_id
	"
    }


    set obj_exists_p [db_string oexists "select count(*) from acs_objects where object_id = :absence_id"]
    if {!$obj_exists_p} {
	db_dml insert_object "
		INSERT into acs_objects (
			object_id,
			object_type,
			creation_date,
			creation_user,
			creation_ip,
			security_inherit_p
		) values (
			:absence_id,
			'im_user_absence',
			now(),
			:current_user_id,
			'[ns_conn peeraddr]',
			'f'
		)
	"
    }

}

db_release_unused_handles

if { [info exists return_url] } {
    ad_returnredirect "$return_url"
} else {
    ad_returnredirect "index"
}
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
    owner_id:notnull
    start_date:notnull
    end_date:notnull
    description:notnull
    contact_info:notnull
    absence_type_id:notnull
    { submit_save "" }
    { submit_del "" }
}

set exception_count 0
set exception_text ""

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
    
    set exists [db_string absence_exists "select count(*) from im_user_absences where absence_id = :absence_id"]

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
    
}

db_release_unused_handles

if { [info exists return_url] } {
    ad_returnredirect "$return_url"
} else {
    ad_returnredirect "index"
}
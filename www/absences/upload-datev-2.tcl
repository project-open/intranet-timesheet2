# packages/intranet-timesheet2/www/absences/upload-datev-2.tcl
#
#
# Copyright (c) 2013, cognovís GmbH, Hamburg, Germany
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
 

# ---------------------------------------------------------------
# Page Contract
# ---------------------------------------------------------------


ad_page_contract {
    Read a .csv-file with header titles exactly matching
    the data model and insert the data into "im_user_absences"

    @author malte.sussdorff@cognovis.de

} {
    return_url
    upload_file
} 


# ---------------------------------------------------------------
# Security & Defaults
# ---------------------------------------------------------------

set current_user_id [ad_maybe_redirect_for_registration]
set page_title "Upload Absences CSV"
set page_body ""
set context_bar [im_context_bar $page_title]

set add_absences_for_group_p [im_permission $current_user_id "add_absences_for_group"]

if {!$add_absences_for_group_p} {
    ad_return_complaint 1 "You have insufficient privileges to use this page"
    return
}


# ---------------------------------------------------------------
# Get the uploaded file
# ---------------------------------------------------------------

# number_of_bytes is the upper-limit
set max_n_bytes [ad_parameter -package_id [im_package_filestorage_id] MaxNumberOfBytes "" 0]
set tmp_filename [ns_queryget upload_file.tmpfile]
im_security_alert_check_tmpnam -location "upload-datev-2.tcl" -value $tmp_filename
if { $max_n_bytes && ([file size $tmp_filename] > $max_n_bytes) } {
    ad_return_complaint 1 "Your file is larger than the maximum permissible upload size:  [util_commify_number $max_n_bytes] bytes"
    return
}

# strip off the C:\directories... crud and just get the file name
if ![regexp {([^//\\]+)$} $upload_file match company_filename] {
    # couldn't find a match
    set company_filename $upload_file
}

if {[regexp {\.\.} $company_filename]} {
    ad_return_complaint 1 "Filename contains forbidden characters"
}

if {![file readable $tmp_filename]} {
    ad_return_complaint 1 "Unable to read the file '$tmp_filename'. 
Please check the file permissions or contact your system administrator.\n"
    ad_script_abort
}


# ---------------------------------------------------------------
# Extract CSV contents
# ---------------------------------------------------------------

set csv_files_content [fileutil::cat $tmp_filename]
set csv_files [split $csv_files_content "\n"]
set csv_files_len [llength $csv_files]

set separator [im_csv_guess_separator $csv_files]

# Split the header into its fields
set csv_header [string trim [lindex $csv_files 0]]
set csv_header_fields [im_csv_split $csv_header $separator]
ds_comment "$csv_header_fields"

set csv_header_len [llength $csv_header_fields]
set values_list_of_lists [im_csv_get_values $csv_files_content $separator]


# ---------------------------------------------------------------
# Render Page Header
# ---------------------------------------------------------------

# This page is a "streaming page" without .adp template,
# because this page can become very, very long and take
# quite some time.

ad_return_top_of_page "
        [im_header]
        [im_navbar]
"


# ---------------------------------------------------------------
# Start parsing the CSV
# ---------------------------------------------------------------


set linecount 0
set first_date [lindex [lindex $values_list_of_lists 0] 8]
set year [lindex [split $first_date "."] 2]

foreach csv_line_fields $values_list_of_lists {
    incr linecount
    
    set personnel_number [string trimleft [lindex $csv_line_fields 3] 0]
    set employee_name [lindex $csv_line_fields 4]
    set absence_type  [lindex $csv_line_fields 5]
    set absence_start [lindex $csv_line_fields 8]
    set absence_end [lindex $csv_line_fields 9]
    set absence_duration [lindex $csv_line_fields 11]

    ds_comment "$personnel_number from $absence_start => $absence_end $employee_name"
    # Transform the duration
    regsub -all {,} $absence_duration {.} duration_days

    set employee_id [db_string employee "select employee_id from im_employees where personnel_number = :personnel_number" -default ""]
    
    if {"" == $employee_id} {
	ns_write "<li>Error: Can't find employee \"$employee_name\" with personnel number $personnel_number<br>"
	continue
    }

    # We only deal with approved absences
    set absence_status_id [im_absence_status_active]

    # Translate the absence_type
    switch $absence_type {
	U { set absence_type_id 5000}
	GZ { set absence_type_id 5006}
	BT { set absence_type_id 5007}
	default { set absence_type_id 5001}
    }

    # Check if we know of this absence
    set absence_id [db_string absence_id "select absence_id from im_user_absences where owner_id = :employee_id and start_date = to_date(:absence_start,'DD.MM.YYYY')" -default 0]
    
    if {$absence_id} {
	# Absence is to be updated
	db_dml update_absence "update im_user_absences set end_date = to_date(:absence_end,'DD.MM.YYYY'), duration_days = :duration_days, absence_type_id = :absence_type_id, absence_status_id = :absence_status_id, absence_name = :employee_name where absence_id = :absence_id"
	
	# Update the last modified date 
	db_dml update_date "update acs_objects set last_modified = now() where object_id = :absence_id"
	im_audit -object_type im_user_absence -action after_create -object_id $absence_id -status_id $absence_status_id -type_id $absence_type_id
    } else {
	# Create new absence
	set absence_id [db_string new_absence "
		SELECT im_user_absence__new(
			null,
			'im_user_absence',
			now(),
			:current_user_id,
			'[ns_conn peeraddr]',
			null,
			:employee_name,
			:employee_id,
			to_date(:absence_start,'DD.MM.YYYY'),
			to_date(:absence_end,'DD.MM.YYYY'),
			:absence_status_id,
			:absence_type_id,
			null,
			null
		)
	"]

	db_dml update_absence "
		update im_user_absences	set
			duration_days = :duration_days
		where absence_id = :absence_id
	"

	db_dml update_object "
		update acs_objects set
			last_modified = now()
		where object_id = :absence_id
	"
    }

    im_audit -object_type im_user_absence -action after_create -object_id $absence_id -status_id $absence_status_id -type_id $absence_type_id	
}

# Now it is time to set all absences to deleted which where not
# touched in the last 10 minutes as they will not have been in the
# upload file

set deleted_absence_ids [db_list deleted_absences "select absence_id from im_user_absences, acs_objects where absence_id = object_id and acs_objects.last_modified < now() - interval '10 minutes' and absence_type_id in (5000,5001,5006,5007) and absence_status_id = :absence_status_id and to_char(start_date,'YYYY') = :year"]

foreach deleted_absence_id $deleted_absence_ids {
    db_dml delete_absence "update im_user_absences set absence_status_id = [im_absence_status_deleted] where absence_id = :deleted_absence_id"
    ns_write "<li>Cancelled vacation: $deleted_absence_id"
}

# ------------------------------------------------------------
# Render Report Footer

ns_write [im_footer]

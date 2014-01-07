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

set user_id [ad_conn user_id]

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

    set vacation_year  [string trimleft [lindex $csv_line_fields 0] 0]
    if {$vacation_year eq "2013"} {
	set personnel_number [string trimleft [lindex $csv_line_fields 1] 0]
	set vacation_balance [string trimleft [lindex $csv_line_fields 2] 0]
	set lost_days [lindex $csv_line_fields 3]
	set vacation_days_per_year  [lindex $csv_line_fields 4]
	set total_days  [lindex $csv_line_fields 5]
	
	set employee_id [db_string employee "select employee_id from im_employees where personnel_number = :personnel_number" -default ""]
	
	if {"" == $employee_id} {
	    ns_write "<li>Error: Can't find employee with personnel number $personnel_number<br>"
	    continue
	}
	
	if {$lost_days == ""} {set lost_days 0}

	# Transform the duration
	regsub -all {,} $vacation_balance {.} vacation_balance
	regsub -all {,} $lost_days {.} lost_days
	regsub -all {,} $vacation_days_per_year {.} vacation_days_per_year
	regsub -all {,} $total_days {.} total_days
	
	# Update the employee
	set vacation_balance [expr $vacation_balance - $lost_days]
	db_dml update_employee "update im_employees set vacation_balance=:vacation_balance, vacation_days_per_year=:vacation_days_per_year where employee_id = :employee_id"
	# Delete old entitlement
	db_dml delete_entitlement "delete from im_user_leave_entitlements where owner_id = :employee_id"
	set absence_id [db_string new_absence "
	    	SELECT im_user_leave_entitlement__new(
			NULL,
			'im_user_leave_entitlement',
			now(),
			:user_id,
			'[ns_conn peeraddr]',
			null,
			'Jahresurlaub',
			:employee_id,
			'2013-01-01',
			:total_days,
			16000,
			5000,
			''
		)
	"]
	
	ds_comment "upload for $employee_id :: $personnel_number :: $absence_id"
    }
}


# ------------------------------------------------------------
# Render Report Footer

ns_write [im_footer]

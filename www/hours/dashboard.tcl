# /packages/intranet-core/www/projects/dashboard.tcl
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
    Ticket Dashboard

    @author frank.bergmann@project-open.com
} {
    { plugin_id:integer 0 }
}

# ---------------------------------------------------------------
# Security & Defaults
# ---------------------------------------------------------------

set current_user_id [auth::require_login]
set user_admin_p [im_is_user_site_wide_or_intranet_admin $current_user_id]
set page_title  [lang::message::lookup "" intranet-timesheet2.Timesheet_Dashboard "Timesheet Dashboard"]
set page_focus "im_header_form.keywords"
set current_url [ns_conn url]
set today [lindex [split [ns_localsqltimestamp] " "] 0]


# ---------------------------------------------------------------
# Sub-Navbar
# ---------------------------------------------------------------

set letter ""
set menu_select_label "companies_dashboard"
set next_page_url ""
set previous_page_url ""
# set sub_navbar_html [im_company_navbar $letter "/intranet/companies/dashboard" $next_page_url $previous_page_url [list start_idx order_by how_many letter ticket_status_id] $menu_select_label]
set sub_navbar_html ""
set left_navbar_html ""


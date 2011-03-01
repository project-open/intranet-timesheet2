# /packages/intranet-timesheet2/www/hours/other-project.tcl
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
    Display the list of available project for the current user
    in order to allow logging hours on project where the current
    user isn't a member of.

    @param julian_date Variable to pass through for the new page
 
    @author Frank Bergmann (frank.bergmann@project-open.com)
    @creation-date January, 2008
  
} {
    { julian_date "" } 
    { user_id_from_search "" }
}

# ---------------------------------------------------------
# 
# ---------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
if {"" == $user_id_from_search || ![im_permission $user_id "add_hours_all"]} { set user_id_from_search $user_id }
set user_name_from_search [db_string uname "select im_name_from_user_id(:user_id_from_search)"]
set subsite_id [ad_conn subsite_id]
set target "new"
set page_title [lang::message::lookup "" intranet-timesheet2.Choose_projects_for_user "Choose projects for %user_name_from_search%"]
set context_bar [im_context_bar [_ intranet-timesheet2.Choose_project]]

set nbsp "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"


# ---------------------------------------------------------
# 
# ---------------------------------------------------------

set export_var_list [list]
set bulk_actions_list [list [lang::message::lookup "" intranet-timesheet2.Log_Hours "Log Hours"] new Help]

template::list::create \
    -name "other_projects" \
    -multirow multirow \
    -key project_id \
    -has_checkboxes \
    -bulk_actions $bulk_actions_list \
    -bulk_action_export_vars { julian_date user_id_from_search} \
    -elements {
	project_chk {
	    label "<input type=\"checkbox\" 
                          name=\"_dummy\" 
                          onclick=\"acs_ListCheckAll('project_list', this.checked)\" 
                          title=\"Check/uncheck all rows\">"
	    display_template {
		@multirow.project_chk;noquote@
	    }
	}
	project_name {
	    label "[_ intranet-timesheet2.Project]"
	    display_template {
		@multirow.indent;noquote@<a href="/intranet/projects/view?project_id=@multirow.project_id@">@multirow.project_name;noquote@</a>
	    }
	}
    }

set perm_where "
	and main_p.project_id in (
		select	r.object_id_one
		from	acs_rels r
		where	r.object_id_two = :user_id
	)       
"
if {[im_permission $user_id "view_projects_all"]} { set perm_where "" }


set list_sort_order "name"
set sort_integer 0
set sort_legacy  0
if { $list_sort_order=="name" } {
    set sort_order "lower(p.project_name)"
} elseif { $list_sort_order=="order" } {
    set sort_order "p.sort_order"
    set sort_integer 1
} elseif { $list_sort_order=="legacy" } {
    set sort_order "p.tree_sortkey"
    set sort_legacy 1
} else {
    set sort_order "lower(p.project_nr)"
}


db_multirow -extend {project_chk return_url indent} multirow multirow "
	select
		p.project_id,
		p.project_name,
		p.parent_id,
		tree_level(p.tree_sortkey) -1 as tree_level,
		$sort_order as sort_order
	from
		im_projects main_p,
		im_projects p
	where
		main_p.project_status_id in ([join [im_sub_categories [im_project_status_open]] ","])
		and main_p.project_type_id not in ([im_project_type_task], [im_project_type_ticket])
		and main_p.parent_id is null
		and p.project_status_id in ([join [im_sub_categories [im_project_status_open]] ","])
		and p.project_type_id not in ([im_project_type_task], [im_project_type_ticket])
		and p.tree_sortkey between
			main_p.tree_sortkey and
			tree_right(main_p.tree_sortkey)
		$perm_where
	order by
	      p.tree_sortkey
" {
    set indent ""
    for {set i 0} {$i < $tree_level} {incr i} { append indent $nbsp; }

    set return_url [im_url_with_query]
    set project_chk "<input type=\"checkbox\" name=\"project_id\" value=\"$project_id\" id=\"project_list,$project_id\">"
}


multirow_sort_tree multirow project_id parent_id sort_order


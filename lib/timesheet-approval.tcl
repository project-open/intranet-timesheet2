# ----------------------------------------------------------------------
# Inbox for "Business Objects"
# ----------------------------------------------------------------------

set view_name "timesheet_approval_inbox"
set order_by_clause ""
set relationship "assignment_group" 
set relationships {holding_user assignment_group none} 
set object_type ""
set subtype_id ""
set status_id ""

set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "

set sql_date_format "YYYY-MM-DD"
set current_user_id [ad_get_user_id]
set return_url [im_url_with_query]
set view_id [db_string get_view_id "select view_id from im_views where view_name=:view_name"]
set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $current_user_id]

set form_vars [ns_conn form]
if {"" == $form_vars} { set form_vars [ns_set create] }

# Order_by logic: Get form HTTP session or use default
if {"" == $order_by_clause} {
    set order_by [ns_set get $form_vars "wf_inbox_order_by"]
    set order_by_clause [db_string order_by "
		select	order_by_clause
		from	im_view_columns
		where	view_id = :view_id and
			column_name = :order_by
	" -default ""]
}

# Calculate the current_url without "wf_inbox_order_by" variable
set current_url "[ns_conn url]?"
ns_set delkey $form_vars wf_inbox_order_by
set form_vars_size [ns_set size $form_vars]
for { set i 0 } { $i < $form_vars_size } { incr i } {
    set key [ns_set key $form_vars $i]
    if {"" == $key} { continue }
    
    # Security check for cross site scripting
    if {![regexp {^[a-zA-Z0-9_\-]*$} $key]} {
	im_security_alert \
	    -location im_workflow_home_inbox_component \
	    -message "Invalid URL var characters" \
	    -value [ns_quotehtml $key]
	# Quote the harmful keys
	regsub -all {[^a-zA-Z0-9_\-]} $key "_" key
    }
    
    set value [ns_set get $form_vars $key]
    append current_url "$key=[ns_urlencode $value]"
    ns_log Notice "im_workflow_home_inbox_component: i=$i, key=$key, value=$value"
    if { $i < [expr $form_vars_size-1] } { append url_vars "&" }
}

if {"" == $order_by_clause} {
    set order_by_clause [parameter::get_from_package_key -package_key "intranet-workflow" -parameter "HomeInboxOrderByClause" -default "creation_date"]
}

# Let Admins see everything
if {[im_is_user_site_wide_or_intranet_admin $current_user_id]} { set relationship "none" }

    # Set relationships based on a single variable
case $relationship {
    holding_user { set relationships {my_object holding_user}}
    my_object { set relationships {my_object holding_user}}
    specific_assignment { set relationships {my_object holding_user specific_assigment}}
    assignment_group { set relationships {my_object holding_user specific_assigment assignment_group}}
    object_owner { set relationships {my_object holding_user specific_assigment assignment_group object_owner}}
    object_write { set relationships {my_object holding_user specific_assigment assignment_group object_owner object_write}}
    object_read { set relationships {my_object holding_user specific_assigment assignment_group object_owner object_write object_read}}
    none { set relationships {my_object holding_user specific_assigment assignment_group object_owner object_write object_read none}}
}

# ---------------------------------------------------------------
# Columns to show

set column_sql "
	select	column_id,
		column_name,
		column_render_tcl,
		visible_for,
		(order_by_clause is not null) as order_by_clause_exists_p
	from	im_view_columns
	where	view_id = :view_id
	order by sort_order, column_id
    "

set column_vars [list]
set colspan 1
set table_header_html "<tr class=\"list-header\">\n"

db_foreach column_list_sql $column_sql {
    if {"" == $visible_for || [eval $visible_for]} {
	lappend column_vars "$column_render_tcl"
	regsub -all " " $column_name "_" col_txt
	set col_txt [lang::message::lookup "" intranet-workflow.$col_txt $column_name]
	set col_url [export_vars -base $current_url {{wf_inbox_order_by $column_name}}]
	set admin_link "<a href=[export_vars -base "/intranet/admin/views/new-column" {return_url column_id {form_mode edit}}] target=\"_blank\">[im_gif wrench]</a>"
	if {!$user_is_admin_p} { set admin_link "" }
	if {"f" == $order_by_clause_exists_p} {
	    append table_header_html "<th class=\"list\">$col_txt$admin_link</td>\n"
	} else {
	    append table_header_html "<th class=\"list\"><a href=\"$col_url\">$col_txt</a>$admin_link</td>\n"
	}
	incr colspan
    }
}

append table_header_html "</tr>\n"


# ---------------------------------------------------------------
# SQL Query

# Get the list of all "open" (=enabled or started) tasks with their assigned users
set tasks_sql "
	select
		o.object_id,
		o.creation_user as owner_id,
		o.creation_date,
		im_name_from_user_id(o.creation_user) as owner_name,
		acs_object__name(o.object_id) as object_name,
		im_biz_object__get_type_id(o.object_id) as type_id,
		im_biz_object__get_status_id(o.object_id) as status_id,
		tr.transition_name,
		t.holding_user,
		t.task_id,
        wta.party_id as assignee_id,
        h.hours
	from
		acs_objects o,
		wf_cases ca left outer join (select sum(hours) as hours, conf_object_id as task_id from im_hours group by conf_object_id) h on h.task_id = ca.object_id,
		wf_transitions tr,
		wf_tasks t,
                wf_task_assignments wta
	where
                wta.task_id = t.task_id
                and (wta.party_id = :user_id or o.creation_user = :user_id)
		and o.object_id = ca.object_id
		and ca.case_id = t.case_id
		and t.state in ('enabled', 'started')
		and t.transition_key = tr.transition_key
		and t.workflow_key = tr.workflow_key
                and t.workflow_key = 'timesheet_approval_wf'
    "

if {"" != $order_by_clause} {
    append tasks_sql "\torder by $order_by_clause"
}

# ---------------------------------------------------------------
# Store the conf_object_id -> assigned_user relationship in a Hash array
set tasks_assignment_sql "
    	select
		t.*,
		m.member_id as assigned_user_id
	from
		($tasks_sql) t
		LEFT OUTER JOIN (
			select distinct
				m.member_id,
				ta.task_id
			from	wf_task_assignments ta,
				party_approved_member_map m
			where	m.party_id = ta.party_id
		) m ON t.task_id = m.task_id
    "
db_foreach assigs $tasks_assignment_sql {
    set assigs ""
    if {[info exists assignment_hash($object_id)]} { set assigs $assignment_hash($object_id) }
    lappend assigs $assigned_user_id
    set assignment_hash($object_id) $assigs
}


# ---------------------------------------------------------------
# Format the Result Data

set ctr 0
set table_body_html ""

db_foreach tasks $tasks_sql {
    
    set rel "assignment_group" 
    
    if {[lsearch $relationships $rel] == -1} { continue }
    
    
    
    regsub -all "#" $transition_name "" transition_key
    if {$transition_name ne $transition_key} {
	set next_action_l10n [lang::message::lookup "" $transition_key]
    } else {
	# L10ned version of next action
	regsub -all " " $transition_name "_" next_action_key
	set next_action_l10n [lang::message::lookup "" intranet-workflow.$next_action_key $transition_name]
    }
    set object_subtype [im_category_from_id $type_id]
    set status [im_category_from_id $status_id]
    set object_url "[im_biz_object_url $object_id "view"]&return_url=[ns_urlencode $return_url]"
    set owner_url [export_vars -base "/intranet/users/view" {return_url {user_id $owner_id}}]

    set approve_url [export_vars -base "/[im_workflow_url]/task" -url {{attributes.confirm_hours_are_the_logged_hours_ok_p t} {action.finish "Task done"} {autoprocess_p 1} task_id return_url}]
    set deny_url [export_vars -base "/[im_workflow_url]/task" -url {{attributes.confirm_hours_are_the_logged_hours_ok_p f} {action.finish "Task done"} {autoprocess_p 1} task_id return_url}]

    # if this is the creator viewing it, prevent him from approving it
    # himself
    if {$owner_id == $user_id && $assignee_id != $user_id} {
        set approve_url [export_vars -base "/[im_workflow_url]/task" {return_url task_id}]
        set next_action_l10n "View"
        set deny_url ""
    }


    
    # Don't show the "Action" link if the object is mine...
    if {"my_object" == $rel} {
	set action_link $next_action_l10n
    } 
    
    set action_link "asdf"
    
    # L10ned version of the relationship of the user to the object
    set relationship_l10n [lang::message::lookup "" intranet-workflow.$rel $rel]
    
    set row_html "<tr$bgcolor([expr $ctr % 2])>\n"
    foreach column_var $column_vars {
	append row_html "\t<td valign=top>"
	set cmd "append row_html $column_var"
	eval "$cmd"
	append row_html "</td>\n"
    }
    append row_html "</tr>\n"
    append table_body_html $row_html
    incr ctr
}

# Show a reasonable message when there are no result rows:
if { [empty_string_p $table_body_html] } {
    set table_body_html "
	<tr><td colspan=$colspan><ul><li><b> 
	[lang::message::lookup "" intranet-core.lt_There_are_currently_n "There are currently no entries matching the selected criteria"]
	</b></ul></td></tr>"
}

# ---------------------------------------------------------------
# Return results

set admin_action_options ""
if {$user_is_admin_p} {
    set admin_action_options "<option value=\"nuke\">[lang::message::lookup "" intranet-workflow.Nuke_Object "Nuke Object (Admin only)"]</option>"
}

set table_action_html "
	<tr class=rowplain>
	<td colspan=99 class=rowplain align=right>
	    <select name=\"operation\">
	    <option value=\"delete_membership\">[lang::message::lookup "" intranet-workflow.Remove_From_Inbox "Remove from Inbox"]</option>
	    $admin_action_options
	    </select>
	    <input type=submit name=submit value='[lang::message::lookup "" intranet-workflow.Submit "Submit"]'>
	</td>
	</tr>
    "
set enable_bulk_action_p [parameter::get_from_package_key -package_key "intranet-workflow" -parameter "EnableWorkflowInboxBulkActionsP" -default 0]
if {!$enable_bulk_action_p} { set table_action_html "" }

set return_url [ad_conn url]?[ad_conn query]



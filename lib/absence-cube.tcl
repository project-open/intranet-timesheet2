
#ad_page_contract {
#    Returns a rendered cube with a graphical absence display
#    for users.
#} {
#    {-num_days 21}
#    {-absence_status_id "" }
#    {-absence_type_id "" }
#    {-user_selection "" }
#    {-timescale "" }
#    {-report_start_date "" }
#    {-report_end_date "" }
#    {-user_id_from_search "" }
#    {-user_id ""}
#    {-cost_center_id ""}
#    {-hide_colors_p 0}
#    {-project_id ""}
#}

set current_user_id [ad_get_user_id]
set view_absences_all_p [im_permission $current_user_id "view_absences_all"]
set user_selection_type $user_selection

if {[string is integer -strict $user_selection]} {
    # Find out the object_type
    set object_type [db_string object_type "select object_type from acs_objects where object_id = :user_selection" -default ""]
    switch $object_type {
        im_cost_center {
            set user_name [im_cost_center_name $user_selection]
            # Allow the manager to see the department
            ns_log Notice "User:: $user_id $user_selection"
            if {![im_manager_of_cost_center_p -user_id $current_user_id -cost_center_id $user_selection] && !$view_absences_all_p} {
            # Not a manager => Only see yourself
            set user_selection_type "mine"
            } else {
            set cost_center_id $user_selection
            set user_selection_type "cost_center"
            set user_selection_id $cost_center_id
            }
        }
        user {
            set user_name [im_name_from_user_id $user_selection]
            set user_id $user_selection
            set user_selection_id $user_id

            # Check for permissions if we are allowed to see this user
            if {$view_absences_all_p} {
            # He can see all users
            set user_selection_type "user"
            } elseif {[im_manager_of_user_p -manager_id $current_user_id -user_id $user_id]} {
            # He is a manager of the user
            set user_selection_type "user"
            set user_selection_id $user_id
            } elseif {[im_supervisor_of_employee_p -supervisor_id $current_user_id -employee_id $user_id]} {
            # He is a supervisor of the user
            set user_selection_type "user"
            set user_selection_id $user_id
            } else {
            # He is cheating
            set user_selection_type "mine"
            }	      
        }
        im_project {
            set project_id $user_selection
            # Permission Check
            set project_manager_p [im_biz_object_member_p -role_id 1301 $current_user_id $project_id]
            if {!$project_manager_p && !$view_absences_all_p} {
            set user_selection_type "mine"
            } else {
            set user_name [db_string project_name "select project_name from im_projects where project_id = :project_id" -default ""]
            set hide_colors_p 1
            set user_selection_type "project"
            set user_selection_id $project_id
            }
        }
        default {
            ad_return_complaint 1 "Invalid User Selection:<br>Value '$user_selection' is not a user_id, project_id, department_id or one of {mine|all|employees|providers|customers|direct reports}."
        }
    }
}

set html ""
switch $timescale {
    today { 
        return
    }
    all { 
        set html [lang::message::lookup "" intranet-timesheet2.AbsenceCubeNotShownAllAbsences "Graphical view of absences not available for Timescale option 'All'. Please choose a different option."]
        return
    }
    custom {
        if {[catch {
            set num_days [db_string get_number_days "select (:report_end_date::date - :report_start_date::date);" -default 0]
            incr num_days
        } err_msg]} {
            set num_days 93
        }
    }
    next_3w { set num_days 21 }
    last_3w { set num_days 21 }
    next_1m { set num_days 31 }
    past { 
        set html [lang::message::lookup "" intranet-timesheet2.AbsenceCubeNotShownPastAbsences "Graphical view of absences not available for Timescale option 'Past'. Please choose a different option."]
        return
        return
    }
    future { set num_days 93 }
    last_3m { set num_days 93 }
    next_3m { set num_days 93 }
    default {
        set num_days 31
    }
}

if { $num_days > 370 } {
    set html [lang::message::lookup "" intranet-timesheet2.AbsenceCubeNotShownGreateOneYear "Graphical view of absences only available for periods less than 1 year"]
    return 
    return
}


set user_url "/intranet/users/view"
set date_format "YYYY-MM-DD"
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "
set name_order [parameter::get -package_id [apm_package_id_from_key intranet-core] -parameter "NameOrder" -default 1]

# ---------------------------------------------------------------
# Limit the number of users and days
# ---------------------------------------------------------------

if {"" == $report_start_date || "2000-01-01" == $report_start_date} {
    set report_start_date [db_string start_date "select now()::date"]
}

if {"" == $report_end_date} {
    set report_end_date [db_string end_date "select :report_start_date::date + 21"]	
}

if {[catch {
    set num_days [db_string get_number_days "select (:report_end_date::date - :report_start_date::date)" -default 0]
    incr num_days
} err_msg]} {
    set num_days 21
}

if {$num_days > 370} {
    set html [lang::message::lookup "" intranet-timesheet2.AbsenceCubeNotShownGreateOneYear "Graphical view of absences only available for periods less than 1 year"]
    return
}

if {-1 == $absence_type_id} { set absence_type_id "" }


# ---------------------------------------------------------------
# Calculate SQL
# ---------------------------------------------------------------

set criteria [list]
if {"" != $absence_type_id && 0 != $absence_type_id} {
    lappend criteria "a.absence_type_id = '$absence_type_id'"
}
if {"" != $absence_status_id && 0 != $absence_status_id} {
    lappend criteria "a.absence_status_id in ([template::util::tcl_to_sql_list [im_sub_categories $absence_status_id]])"
} else {
    # Only display active status if no other status was selected
    lappend criteria "a.absence_status_id in ([template::util::tcl_to_sql_list [im_sub_categories [im_user_absence_status_active]]])"

}

switch $user_selection_type {
    "all" {
        # Nothing.
    }
    "mine" {
        lappend criteria "u.user_id = :current_user_id"
    }
    "employees" {
        lappend criteria "u.user_id IN (
            select	m.member_id
            from	group_approved_member_map m
            where	m.group_id = [im_employee_group_id]
        )"
    }
    "providers" {
        lappend criteria "u.user_id IN (
            select	m.member_id 
            from	group_approved_member_map m 
            where	m.group_id = [im_freelance_group_id]
        )"
    }
    "customers" {
        lappend criteria "u.user_id IN (
            select	m.member_id
            from	group_approved_member_map m
            where	m.group_id = [im_customer_group_id]
        )"
    }
    "direct_reports" {
        lappend criteria "a.owner_id in (
            select employee_id from im_employees
            where (supervisor_id = :current_user_id OR employee_id = :current_user_id)
            UNION
            select	e.employee_id 
            from	im_employees e,
            -- Select all departments where the current user is manager
            (select	cc.cost_center_id,
             cc.manager_id
             from	im_cost_centers cc,
             (select cost_center_code as code,
              length(cost_center_code) len
              from	im_cost_centers
              where	manager_id = :current_user_id
              ) t
             where	substring(cc.cost_center_code for t.len) = t.code
             ) tt
            where  (e.department_id = tt.cost_center_id
                OR e.employee_id = tt.manager_id)
        )"
    }  
    "cost_center" {
        set cost_center_id $user_selection_id
        set cost_center_list [im_cost_center_options -parent_id $cost_center_id]
        set cost_center_ids [list $cost_center_id]
        foreach cost_center $cost_center_list {
            lappend cost_center_ids [lindex $cost_center 1]
        }
        lappend criteria "a.owner_id in (select employee_id from im_employees where department_id in ([template::util::tcl_to_sql_list $cost_center_ids]) and employee_status_id = '454')"
    }
    "project" {
        set project_id $user_selection_id
        set project_ids [im_project_subproject_ids -project_id $project_id]
        lappend criteria "a.owner_id in (select object_id_two from acs_rels where object_id_one in ([template::util::tcl_to_sql_list $project_ids]))"
    }
    "user" {
        set user_id $user_selection_id
        lappend criteria "a.owner_id=:user_id"
    }	    
    default  {
        # We shouldn't even be here, so just display his/her own ones
        lappend criteria "a.owner_id = :current_user_id"
    }
}

set where_clause [join $criteria " and\n            "]
if {![empty_string_p $where_clause]} {
    set where_clause " and $where_clause"
}

# ---------------------------------------------------------------
# Determine Top Dimension
# ---------------------------------------------------------------

# Initialize the hash for holidays.
array set holiday_hash {}

set sql "select to_char(to_date(:report_start_date,:date_format) + interval '$num_days days', :date_format)"
set absence_week_days \
    [im_absence_week_days \
        -start_date $report_start_date \
        -end_date [db_string end_date $sql]]

foreach weekend_date $absence_week_days {
    set holiday_hash($weekend_date) 5
}
set day_list \
    [im_absence_day_list \
        -date_format $date_format \
        -num_days $num_days \
        -report_start_date $report_start_date]

# ---------------------------------------------------------------
# Determine Left Dimension
# ---------------------------------------------------------------

set user_list [db_list_of_lists user_list "
    select	u.user_id as user_id,
    im_name_from_user_id(u.user_id, $name_order) as user_name
    from	users u,
    cc_users cc
    where	u.user_id in (
      -- Individual Absences per user
      select	a.owner_id
      from	im_user_absences a,
            users u
      where	a.owner_id = u.user_id and
            a.start_date <= :report_end_date::date and
            a.end_date >= :report_start_date::date
            $where_clause
      UNION
      -- Absences for user groups
      select	mm.member_id as owner_id
      from	im_user_absences a,
            users u,
      group_distinct_member_map mm
      where	mm.member_id = u.user_id and
            a.start_date <= :report_end_date::date and
            a.end_date >= :report_start_date::date and
            mm.group_id = a.group_id
            $where_clause
    )
    and cc.member_state = 'approved'
    and cc.user_id = u.user_id
    order by
    lower(im_name_from_user_id(u.user_id, $name_order))
"]


# Get list of category_ids to determine index 
# needed for color codes

set sql "
    select  category_id
    from    im_categories
    where   category_type = 'Intranet Absence Type'
    order by category_id
"

set category_list [list]
db_foreach category_id $sql {
    lappend category_list [list $category_id]
}

# ---------------------------------------------------------------
# Get individual absences
# ---------------------------------------------------------------

array set absence_hash {}
set absence_sql "
    -- Individual Absences per user
    select	a.absence_type_id,
            a.owner_id,
            d.d
    from	im_user_absences a,
            users u,
            (select im_day_enumerator as d from im_day_enumerator(:report_start_date, :report_end_date)) d,
            cc_users cc
    where	a.owner_id = u.user_id and
            cc.user_id = u.user_id and 
            cc.member_state = 'approved' and
            a.start_date <= :report_end_date::date and
            a.end_date >= :report_start_date::date and
            date_trunc('day',d.d) between date_trunc('day',a.start_date) and date_trunc('day',a.end_date) 
            $where_clause
    UNION
    -- Absences for user groups
    select	a.absence_type_id,
            mm.member_id as owner_id,
            d.d
    from	im_user_absences a,
            users u,
            group_distinct_member_map mm,
            (select im_day_enumerator as d from im_day_enumerator(:report_start_date, :report_end_date)) d
    where	mm.member_id = u.user_id and
            a.start_date <= :report_end_date::date and
            a.end_date >= :report_start_date::date and
            date_trunc('day',d.d) between date_trunc('day',a.start_date) and date_trunc('day',a.end_date) and 
            mm.group_id = a.group_id
            $where_clause
    UNION
    -- Absences for bridge days
    select	a.absence_type_id,
            mm.member_id as owner_id,
            d.d
    from	im_user_absences a,
            users u,
            group_distinct_member_map mm,
            (select im_day_enumerator as d from im_day_enumerator(:report_start_date, :report_end_date)) d
    where	mm.member_id = u.user_id and
            a.start_date <= :report_end_date::date and
            a.end_date >= :report_start_date::date and
            date_trunc('day',d.d) between date_trunc('day',a.start_date) and date_trunc('day',a.end_date) and 
            mm.group_id = a.group_id and
            a.absence_type_id in ([template::util::tcl_to_sql_list [im_sub_categories [im_user_absence_type_bank_holiday]]]) and
            a.absence_status_id in ([template::util::tcl_to_sql_list [im_sub_categories [im_user_absence_status_active]]])
"

# TODO: re-factor so that color codes also work in case of more than 10 absence types
db_foreach absences $absence_sql {
    set key "$owner_id-$d"
    set value [get_value_if absence_hash(${key}) ""]
    set absence_hash($key) [append value [lsearch $category_list $absence_type_id]]
}

# ---------------------------------------------------------------
# Render the table
# ---------------------------------------------------------------

set table_header "<tr class=rowtitle>\n"
append table_header "<td class=rowtitle>[_ intranet-core.User]</td>\n"
foreach day $day_list {
    set date_date [lindex $day 0]
    set date_day_of_month [lindex $day 1]
    set date_month_of_year [lindex $day 2]
    set date_year [lindex $day 3]
    append table_header "<td class=rowtitle>$date_month_of_year<br>$date_day_of_month</td>\n"
}

append table_header "</tr>\n"
set row_ctr 0
set table_body ""
foreach user_tuple $user_list {
    append table_body "<tr $bgcolor([expr $row_ctr % 2])>\n"
    set user_id [lindex $user_tuple 0]
    set user_name [lindex $user_tuple 1]
    append table_body "<td><nobr><a href='[export_vars -base $user_url {user_id}]'>$user_name</a></td></nobr>\n"
    foreach day $day_list {
        set date_date [lindex $day 0]
        set key "$user_id-$date_date"

        set value [get_value_if absence_hash(${key}) ""]

        if {[info exists holiday_hash($date_date)]} { 
            append value $holiday_hash($date_date) 
        }
        if {$hide_colors_p && $value != "" } {
            set value "1"
        }
        append table_body [im_absence_cube_render_cell $value]
        ns_log debug "intranet-absences-procs::im_absence_cube_render_cell: $value"
    }
    append table_body "</tr>\n"
    incr row_ctr
}

set html "
<table>
$table_header
$table_body
</table>
"


# /packages/intranet-timesheet2/tcl/test/basic-timesheet-logging-procs.tcl
#
# Copyright (C) 2024 Frank Bergmann (frank.bergmann@project-open.com)

ad_library {
    Test procedures for intranet-timesheet2
    @author frank.bergmann@project-open.com
    @creation-date 2024-11-10
}

ad_proc -public timesheet_test_basic_teardown {
} {
    Delete the objects previously created
} {
    set invoice_ids [db_list test_ids "select object_id from acs_objects where creation_ip = '1.1.1.1' and object_type in ('im_invoice')"]
    foreach id $invoice_ids { aa_log "teardown invoice #$id"; im_invoice_nuke $id }

    set ids [db_list test_ids "select object_id from acs_objects where creation_ip = '1.1.1.1' and object_type not in ('im_cost_center')"]
    foreach id $ids { aa_log "teardown non-cc #$id"; db_string del "select acs_object__delete(:id)" }

    set ids [db_list test_ids "select object_id from acs_objects where creation_ip = '1.1.1.1' and object_type in ('im_cost_center')"]
    foreach id $ids { aa_log "teardown cc #$id"; db_string del "select acs_object__delete(:id)" }
}


ad_proc -public timesheet_test_basic {
    -user_id
} {
    Setup a Purchase Order approval workflow.
    @param user_id user_id of admin user created for testing
} {
    # Get some users
    set employees [db_list senmans "select member_id from group_distinct_member_map where group_id in (select group_id from groups where group_name = 'Employees') order by member_id"]
    set project_managers [db_list pms "select u.user_id from users u, group_distinct_member_map gdmm where u.user_id = gdmm.member_id and gdmm.group_id in (select group_id from groups where group_name = 'Project Managers') order by member_id"]
    set pm1_id [lindex $project_managers 0]
    set emp1_id [lindex $employees 0]
    set sa1_id 624

    # Get today
    set today_julian [db_string today_julian "select to_char(now()::date, 'J')"]

    # Setup a project with two tasks, one below each other
    set project_id [im_project::twt::new -type_id [im_project_type_gantt] -project_manager_id $pm1_id]
    set task1_id [im_project::twt::new -type_id [im_project_type_task] -parent_id $project_id]
    set task2_id [im_project::twt::new -type_id [im_project_type_task] -parent_id $task1_id]
    db_dml project "update im_projects set start_date = now(), end_date = now() + '1 month'::interval where project_id in (:project_id, :task1_id, :task2_id)"

    foreach pid [list $project_id $task1_id $task2_id] {
	foreach uid [list $pm1_id $emp1_id $user_id $sa1_id] {
	    im_biz_object_add_role $uid $pid [im_biz_object_role_full_member]
	}
    }

    # Log hours on the sub-task task2
    set ts_url [export_vars -base "/intranet-timesheet2/hours/new" {{julian_date $today_julian} {show_week_p 0}}]
    aa_log "timesheet_test_basic: user=$user_id, pm1=$pm1_id, emp1=$emp1_id, project_id=$project_id, ts_url=$ts_url"
    ::twt::do_request $ts_url 

    aa_log "timesheet_test_basic: before form find"
    tclwebtest::form find ~n "timesheet"
    aa_log "timesheet_test_basic: before field find hours0.$task2_id"
    tclwebtest::field find ~n "hours0.$task2_id"
    tclwebtest::field fill "1.23"
    tclwebtest::field find ~n "notes0.$task2_id"
    tclwebtest::field fill "1.23 random comment"
    tclwebtest::form submit

    set response_url [tclwebtest::response url]	
    set response_body [tclwebtest::response body]
    set response_text [tclwebtest::response text]
    # set response_text [cosine_test_cash_flow_extract_table $response_body]
    aa_log $response_url
    aa_log $response_text

}


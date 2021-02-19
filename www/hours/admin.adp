<master>
<property name="doc(title)">@page_title;literal@</property>
<property name="admin_navbar_label">admin_home</property>

    <H2>Timesheet2 User Documentation</H2>
    <ul>
      <li><a href="https://www.project-open.com/en/tutorial-timesheet-management" target="_blank">Timesheet - User Documentation</a>
      <li><a href="https://www.project-open.com/en/process-pm-project-timesheet-mangement" target="_blank">Timesheet - General process description</a>
      <li><a href="https://www.project-open.com/en/report-timesheet-weekly-view" target="_blank">Timesheet - Weekly Report</a>
      <li><a href="https://www.project-open.com/en/report-timesheet-productivity-calendar-view-simple" target="_blank">Timesheet - Productivity report (calendar view)</a>
      <li><a href="https://www.project-open.com/en/report-timesheet-productivity" target="_blank">Timesheet - Productivity report</a>
    </ul>


    <H2>Timesheet2 Admin Documentation</H2>
    <ul>
      <li><a href="https://www.project-open.com/en/timesheet-configuration" target="_blank">Timesheet - Tutorial Configuration</a>
      <li><a href="https://www.project-open.com/en/configuration-ts-approval-workflow" target="_blank">Timesheet Approval Workflow - Configuration</a>
      <li><a href="https://www.project-open.com/en/object-type-im-hour" target="_blank">Timesheet - "Hour" object database documentation</a>
      <li><a href="https://www.project-open.com/en/object-type-im-timesheet-conf-object" target="_blank">Timesheet - "Confirmation Object database documentation</a>
      <li><a href="https://www.project-open.com/en/list-tables-gantt-ts" target="_blank">Timesheet - Database tables overview</a>
      <li><a href="https://www.project-open.com/en/package-intranet-timesheet2-workflow" target="_blank">Timesheet Workflow - Package documentation</a>
      <li><a href="https://www.project-open.com/en/package-intranet-timesheet2" target="_blank">Timesheet - Package documentation</a>
      <li><a href="https://www.project-open.com/en/package-intranet-timesheet-reminders" target="_blank">Timesheet Reminders - Package documentation</a>
    </ul>



    <H2>Timesheet2 Administration</H2>
    <ul>
      <li><a href="/shared/parameters?package_id=<%= [db_string pid "select package_id from apm_packages where package_key = 'intranet-timesheet2'" -default 0] %>" target="_blank">Timesheet - Parameters</a>
      <li><a href="/shared/parameters?package_id=<%= [db_string pid "select package_id from apm_packages where package_key = 'intranet-timesheet2-workflow'" -default 0] %>" target="_blank">Timesheet Workflow - Parameters</a>
      <li><a href="/intranet/admin/categories/index?select_category_type=Intranet+Timesheet+Conf+Status" target="_blank">Timesheet Workflow - Confirmation Object Status</a>
      <li><a href="/intranet/admin/categories/index?select_category_type=Intranet+Timesheet+Conf+Type" target="_blank">Timesheet Workflow - Confirmation Object Type</a>
    </ul>


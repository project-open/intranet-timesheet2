
<if @view_absences_p@ or @view_absences_all_p@>


<table>
<tr class=rowtitle>
	<td colspan=2 class=rowtitle><%= [lang::message::lookup "" intranet-timesheet2.Vacation_Balance "Vacation Balance"] %></td>
</tr>
<tr class=roweven>
	<td><%= [lang::message::lookup "" intranet-timesheet2.User User] %></td>
	<td>@user_name@</td>
</tr>
<tr class=rowodd>
	<td><%= [lang::message::lookup "" intranet-timesheet2.Time_Period "Period"] %></td>
	<td>@start_of_year@ - @end_of_year@</td>
</tr>
<tr class=roweven>
	<td><%= [lang::message::lookup "" intranet-timesheet2.Vacation_Days_per_Year "Vacation Days per Year"] %></td>
	<td>@vacation_days_per_year@</td>
</tr>
<tr class=rowodd>
	<td><%= [lang::message::lookup "" intranet-timesheet2.Vacation_Balance_From_Last_Year "Vacation Balance from Last Year"] %></td>
	<td>@vacation_balance@</td>
</tr>
<tr class=rowodd>
	<td><%= [lang::message::lookup "" intranet-timesheet2.Vacation_Taken_This_Year "Vacation Taken This Year"] %></td>
	<td>@vacation_days_taken@</td>
</tr>
<tr class=rowodd>
	<td><%= [lang::message::lookup "" intranet-timesheet2.Vacation_Left_for_Period "Vacation Days Left for Period"] %></td>
	<td>@vacation_days_left@</td>
</tr>
</table>

<br>
<listtemplate name="vacation_balance"></listtemplate>


</if>


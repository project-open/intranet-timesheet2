<if @view_absences_p@ or @view_absences_all_p@>
<table width=100%>
<tbody>
<tr>
<td class="rowtitle">#intranet-timesheet2.Attibute_Type#</td>
<td class="rowtitle">#intranet-timesheet2.Remaining_Days#</td>
<td class="rowtitle">#intranet-timesheet2.Requested_Days#</td>
</tr>
<multiple name="absence_balance">
  <if @absence_balance.requested_days@ eq "0" and @absence_balance.remaining_days@ eq "0">
  </if>
<else>
      <tr>
        <td align="left" valign="top" class="attribute" width="20%">@absence_balance.absence_type;noquote@:</td>
        <td align="left" valign="top" class="value">@absence_balance.remaining_days;noquote@</td>
        <td align="left" valign="top" class="value">@absence_balance.requested_days;noquote@</td>
      </tr>
</else>
</multiple>
</tbody>
</table>
</if>



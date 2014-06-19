<form method=POST action=/intranet-timesheet2/absences/new id="absence" name="absence">
    <input type="hidden" name="form:mode" value="display" >
    <input type="hidden" name="form:id" value="absence" >
    <input type="hidden" name="absence_id" value="@absence_id;noquote@">
    <input type="hidden" name="return_url" value="@return_url;noquote@">
    <table cellpadding=0 cellspacing=2 border=0>
    <multiple name="user_columns">
    <if @user_columns.visible_p@ eq 1>
      <tr @user_columns.td_class;noquote@>
        <td>@user_columns.column_name;noquote@ &nbsp;</td>
        <td>@user_columns.column_render;noquote@</td>
      </tr>
    </if>
    </multiple>
    <tr class="form-element">
      <td align="left" colspan="2">
        @actions_html;noquote@
      </td>
    </tr>
    </table>
 </form>
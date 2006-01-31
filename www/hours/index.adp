<master src="../../../intranet-core/www/master">
<property name="title">@page_title;noquote@</property>
<property name="context">#intranet-timesheet2.context#</property>
<property name="main_navbar_label">finance</property>

<if "" ne @message@>
<h1>@header@</h1>
<div class="form-error">
@message@
</div>
<p>
</if>

@page_body;noquote@






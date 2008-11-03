<master src="../../../intranet-core/www/master">
<property name="title">@page_title;noquote@</property>
<property name="context">#intranet-timesheet2.context#</property>
<property name="main_navbar_label">timesheet2_timesheet</property>

<div class="filter-list">
  <a id="sideBarTab" href="#"><img id="sideBarTabImage" border="0" title="sideBar" alt="sideBar" src="/intranet/images/navbar_saltnpepper/slide-button-active.gif"/></a>
  <div class="filter" id="sidebar">
    <div id="sideBarContentsInner">
      <div class="filter-block">
        <div class="filter-title">#intranet-timesheet2.Timesheet#</div>
      </div>
      <hr/>
      <%= [im_navbar_tree -label "main"] %>
    </div>
  </div>
</div>



<div class="fullwidth-list" id="fullwidth-list">

<if "" ne @message@>
<h1>@header@</h1>

<table width="70%">
   <tr>
      <td>
         <div class="form-error">
            @message;noquote@
         </div>
      </td>
   </tr>
</table>

<p></p>
</if>

<%= [im_table_with_title $page_title $page_body] %>

</div>





<%@ page import="ru.org.linux.site.Template" %>
<%--
  ~ Copyright 1998-2015 Linux.org.ru
  ~    Licensed under the Apache License, Version 2.0 (the "License");
  ~    you may not use this file except in compliance with the License.
  ~    You may obtain a copy of the License at
  ~
  ~        http://www.apache.org/licenses/LICENSE-2.0
  ~
  ~    Unless required by applicable law or agreed to in writing, software
  ~    distributed under the License is distributed on an "AS IS" BASIS,
  ~    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  ~    See the License for the specific language governing permissions and
  ~    limitations under the License.
  --%>
<%@ page contentType="text/html; charset=utf-8"%>
<%@ taglib uri="http://java.sun.com/jsp/jstl/functions" prefix="fn" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%--@elvariable id="template" type="ru.org.linux.site.Template"--%>
<c:if test="${empty template}">
    <c:set var="template" value="<%= Template.getTemplate(request) %>"/>
</c:if>

<link rel="search" title="Search" href="/search.jsp">

<base href="${fn:escapeXml(template.secureMainUrl)}">

<jsp:include page="${template.theme.headMain}"/>

<div id="bd">
<!-- end of header-main.jsp -->

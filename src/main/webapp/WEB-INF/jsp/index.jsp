<%@ page contentType="text/html; charset=utf-8"%>
<%@ page import="ru.org.linux.site.Template"%>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ taglib prefix="lor" uri="http://www.linux.org.ru" %>
<%@ taglib tagdir="/WEB-INF/tags" prefix="lorDir" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>

<%--
~ Copyright 1998-2022 Linux.org.ru
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
<%--@elvariable id="template" type="ru.org.linux.site.Template"--%>
<%--@elvariable id="news" type="java.util.List<ru.org.linux.topic.PersonalizedPreparedTopic>"--%>
<%--@elvariable id="uncommited" type="java.lang.Integer"--%>
<%--@elvariable id="uncommitedNews" type="java.lang.Integer"--%>
<%--@elvariable id="hasDrafts" type="java.lang.Boolean"--%>
<%--@elvariable id="briefNews" type="java.util.List<java.util.List<scala.Tuple2<java.lang.String, java.util.Collection<ru.org.linux.topic.BriefTopicRef>>>>"--%>
<% Template tmpl = Template.getTemplate(request); %>
<jsp:include page="/WEB-INF/jsp/head.jsp"/>

<title>LINUXTALKS.CO — русскоязычное сообщество Linux</title>
<meta name="Keywords" content="linux линукс операционная система документация gnu бесплатное свободное програмное обеспечение софт unix юникс software free documentation operating system новости news">
<meta name="Description" content="Все о Linux на русском языке">
<link rel="alternate" title="L.O.R RSS" href="section-rss.jsp?section=1" type="application/rss+xml">
<jsp:include page="/WEB-INF/jsp/header-main.jsp"/>

<div id="mainpage">
<div id="news">
<nav>
<a href="add-section.jsp?section=1" class="btn btn-primary">Добавить новость</a>
<a class="btn btn-default" href="/view-all.jsp">Неподтвержденные&nbsp;&#40;${uncommited}&#41;</a>
</nav>

<%--
	<c:if test="${template.moderatorSession or template.correctorSession}">
	<div class="nav"   style="border-bottom: none">
	<c:if test="${uncommited > 0}">
	[<a href="view-all.jsp">Неподтвержденных</a>: ${uncommited},
	<c:if test="${uncommitedNews > 0}">
	в том числе <a href="view-all.jsp?section=1">новостей</a>:&nbsp;${uncommitedNews}]
	</c:if>
	<c:if test="${uncommitedNews == 0}">
	новостей нет]
	</c:if>
	</c:if>
	</div>
	</c:if>
--%>
	
	
	<%
	boolean multiPortal = false;

	if (tmpl.getProf().isShowGalleryOnMain()) {
		multiPortal = true;
	}
%>
<c:forEach var="msg" items="${news}">
<lorDir:news preparedMessage="${msg.preparedTopic}" messageMenu="${msg.topicMenu}"
multiPortal="<%= multiPortal %>" moderateMode="false"/>
</c:forEach>

<c:if test="${not empty briefNews}">
<section>
<h2>Еще новости</h2>

<div class="container" id="main-page-news">
<c:forEach var="map" items="${briefNews}" varStatus="iter">
<section>
<c:forEach var="entry" items="${map}">
<h3>${entry._1()}</h3>
<ul>
<c:forEach var="msg" items="${entry._2()}">
<li>
<c:if test="${msg.group.defined}">
<span class="group-label">${msg.group.get()}</span>
</c:if>
<a href="${msg.url}"><l:title>${msg.title}</l:title></a>
<c:if test="${msg.commentCount>0}">(<lorDir:comment-count count="${msg.commentCount}"/>)</c:if>
</li>
</c:forEach>
</ul>
</c:forEach>
</section>
</c:forEach>
</div>
</section>
</c:if>


<p>
<i class="icon-rss"></i>
<a href="section-rss.jsp?section=1">
RSS-подписка на новости
</a>
</p>

</div>

<aside id=boxlets>

<c:if test="${template.sessionAuthorized}">
<div class=boxlet>
<h2>Добро пожаловать!</h2>

<div class="boxlet_content">
Ваш статус: ${template.currentUser.status}
<ul>
<li><a href="/people/${template.nick}/">Мои темы</a></li>
<c:if test="${favPresent}">
<li><a href="/people/${template.nick}/favs">Избранные темы</a></li>
</c:if>
<li><a href="search.jsp?range=COMMENTS&user=${template.nick}&sort=DATE">Мои комментарии</a></li>
<c:if test="${hasDrafts}">
<li>
<a href="/people/${template.nick}/drafts">Черновики</a>
</li>
</c:if>
</ul>
<ul>
<li><a href="/people/${template.nick}/settings">Настройки</a></li>
<li><a href="/people/${template.nick}/edit">Редактировать профиль</a></li>
</ul>
</div>
</div>
</c:if>

<% out.flush(); %>

<lor:boxlets var="boxes">
<c:forEach var="boxlet" items="${boxes}">
<div class="boxlet">
<c:import url="/${boxlet}.boxlet"/>
</div>
</c:forEach>
</lor:boxlets>
</aside>
</div>

<jsp:include page="/WEB-INF/jsp/footer-main.jsp"/>

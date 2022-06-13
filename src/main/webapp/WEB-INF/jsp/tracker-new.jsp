<%@ page info="last active topics" %>
<%@ page contentType="text/html; charset=utf-8" %>
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
<%--@elvariable id="newUsers" type="java.util.List<ru.org.linux.user.User>"--%>
<%--@elvariable id="frozenUsers" type="java.util.List<scala.Tuple2<ru.org.linux.user.User, java.lang.Boolean>>"--%>
<%--@elvariable id="msgs" type="java.util.List<ru.org.linux.group.TopicsListItem>"--%>
<%--@elvariable id="template" type="ru.org.linux.site.Template"--%>
<%--@elvariable id="deleteStats" type="java.util.List<ru.org.linux.site.DeleteInfoStat>"--%>
<%--@elvariable id="filters" type="java.util.List<ru.org.linux.spring.TrackerFilterEnum>"--%>
<jsp:include page="/WEB-INF/jsp/head.jsp"/>
<%@ taglib tagdir="/WEB-INF/tags" prefix="lor" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="form" uri="http://www.springframework.org/tags/form" %>
<%@ taglib prefix="ftm" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="l" uri="http://www.linux.org.ru" %>

<title>${title}</title>
<jsp:include page="/WEB-INF/jsp/header.jsp"/>

<h1>Последние сообщения</h1>

<nav>
  <c:forEach items="${filters}" var="f">
      <c:url var="fUrl" value="/tracker/">
        <c:if test="${f != defaultFilter}">
          <c:param name="filter">${f.value}</c:param>
        </c:if>
      </c:url>
      <c:if test="${filter != f.value}">
        <a class="btn btn-default" href="${fUrl}">${f.label}</a>
      </c:if>
      <c:if test="${filter==f.value}">
        <a href="${fUrl}" class="btn btn-selected">${f.label}</a>
      </c:if>
  </c:forEach>
</nav>

<div class=tracker>
    <c:forEach var="msg" items="${msgs}">
      <a href="${msg.lastPageUrl}" class="tracker-item">
        <div class="tracker-src">
          <p>
          <span class="group-label">${msg.groupTitle}</span>
            <c:if test="${msg.uncommited}">(не подтверждено)</c:if><br class="hideon-phone hideon-tablet">
          <c:if test="${msg.topicAuthor != null}"><lor:user user="${msg.topicAuthor}"/></c:if>
          </p>
        </div>

        <div class="tracker-count">
          <p>
          <c:choose>
            <c:when test="${msg.commentCount==0}">
              -
            </c:when>
            <c:otherwise>
              <i class="icon-comment"></i> ${msg.commentCount}
            </c:otherwise>
          </c:choose>
          </p>
        </div>

        <div class="tracker-title">
          <p>
            <c:if test="${msg.commentsClosed and not msg.deleted}">
                          <i class="icon-pin icon-pin-color" style="font-style:normal;">&#128274;</i>
            </c:if>
            <c:if test="${msg.resolved}">
              <i class="icon-pin-color" style="font-style:normal;">&#9745;</i>
            </c:if>

            <l:title>${msg.title}</l:title>
          </p>
        </div>

        <div class="tracker-tags">
          <p>
          <c:forEach var="tag" items="${msg.tags}">
            <span class="tag">${tag}</span>
          </c:forEach>
          </p>
        </div>

        <div class="tracker-last">
          <p>
          <lor:user user="${msg.author}"/>, <lor:dateinterval date="${msg.postdate}" compact="true"/>
          </p>
        </div>
      </a>
    </c:forEach>
</div>

<div class="nav">
  <div style="display: table; width: 100%">
    <div style="display: table-cell; text-align: left">
      <c:if test="${offset>0}">
        <a href="/tracker/?offset=${offset-topics}${addition_query}">← предыдущие</a>
      </c:if>
    </div>
    <div style="display: table-cell; text-align: right">
      <c:if test="${offset+topics<300 and fn:length(msgs)==topics}">
        <a href="/tracker/?offset=${offset+topics}${addition_query}">следующие →</a>
      </c:if>
    </div>
  </div>
</div>

<c:if test="${not empty newUsers || not empty frozenUsers || not empty blockedUsers || not empty unFrozenUsers || not empty unBlockedUsers}">
  <h2>Пользователи</h2>
  <p>
    Новые пользователи за последние 3 дня:
    <c:forEach items="${newUsers}" var="user">
      <lor:user user="${user}" link="true" bold="${user.activated}"/><c:out value=" "/>
    </c:forEach>
    (всего ${fn:length(newUsers)})
  </p>
  <p>
    Замороженные пользователи:
    <c:forEach items="${frozenUsers}" var="user">
      <lor:user user="${user._1()}" bold="${user._2()}" link="true"/><c:out value=" "/>
    </c:forEach>
    (всего ${fn:length(frozenUsers)})
  </p>
  <p>
    Размороженные пользователи за последние 3 дня:
    <c:forEach items="${unFrozenUsers}" var="user">
      <lor:user user="${user._1()}" bold="${user._2()}" link="true"/><c:out value=" "/>
    </c:forEach>
    (всего ${fn:length(unFrozenUsers)})
  </p>
  <p>
    Заблокированные пользователи за последние 3 дня:
    <c:forEach items="${blockedUsers}" var="user">
      <lor:user user="${user}" link="true"/><c:out value=" "/>
    </c:forEach>
    (всего ${fn:length(blockedUsers)})
  </p>
  <p>
    Разблокированные пользователи за последние 3 дня:
    <c:forEach items="${unBlockedUsers}" var="user">
      <lor:user user="${user}" link="true"/><c:out value=" "/>
    </c:forEach>
    (всего ${fn:length(unBlockedUsers)})
  </p>
</c:if>

<jsp:include page="/WEB-INF/jsp/footer.jsp"/>

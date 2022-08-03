<%@ page contentType="text/html; charset=utf-8" %>
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
<%@ taglib tagdir="/WEB-INF/tags" prefix="lor" %>
<%--@elvariable id="message" type="ru.org.linux.topic.Topic"--%>
<%--@elvariable id="groups" type="java.util.List<Group>"--%>
<%--@elvariable id="sections" type="java.util.Map<Integer, ru.org.linux.section.Section>"--%>
<%--@elvariable id="author" type="ru.org.linux.user.User"--%>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>

<jsp:include page="/WEB-INF/jsp/head.jsp"/>
<title>Вынос</title>
<jsp:include page="/WEB-INF/jsp/header.jsp"/>
<c:if test="${not template.moderatorSession}">
Если вы считаете, что данное сообщение не связано с обсуждаемой темой и носит личный характер,<br>
</c:if>
Вы можете вынести это сообщение (<strong>${message.id}</strong>) и все связанные с ним в отдельную тему. :
<form method="post" action="/move_comment.jsp">
    <lor:csrf/>
    <input type=hidden name="msgid" value="${message.id}">
    <table>
        <tr>
            <td>Раздел: </td>
            <td>
                <select name="moveto">
            	    <c:if test="${template.moderatorSession}">
                    <c:forEach var="group" items="${groups}">
                        <option value="${group.id}">${group.title} (${sections.get(group.sectionId).name})</option>
                    </c:forEach>
                    </c:if>
                    <option value="19390">Клуб</option>
                </select>
            </td>
        </tr>
        <tr>
            <td>Заголовок темы: </td>
            <td><input type='text' name="topicTitle"></td>
        </tr>
    </table>


    <input type='submit' name='move' value='Вынести'>
</form>

сообщение написано
<lor:user user="${author}"/>, score=${author.score}

<jsp:include page="/WEB-INF/jsp/footer.jsp"/>

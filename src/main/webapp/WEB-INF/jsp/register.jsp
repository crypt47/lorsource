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
<%@ page import="ru.org.linux.user.User" %>
<%@ page contentType="text/html; charset=utf-8"%>
<%@ taglib tagdir="/WEB-INF/tags" prefix="lor" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ taglib prefix="form" uri="http://www.springframework.org/tags/form" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/functions" prefix="fn" %>
<jsp:include page="head.jsp"/>

<title>Регистрация пользователя</title>
<script type="text/javascript">
  $script.ready("plugins", function() {
    $(function() {
      $("#registerForm").validate({
        errorElement : "span",
        errorClass : "error help-inline",
        rules : {
          password2: {
            equalTo: "#password"
          },
          nick: {
            remote: "/check-login"
          }
        }
      });
    });
  });
</script>

<jsp:include page="header.jsp"/>
<H1>Регистрация</H1>
<p>
    <div class="help-block" style="max-width:20rem;">
	Для автоматического повышения скора пользователи linux.org.ru могут добавить фразу 'TrueMan' в свой профиль. Автоматическая проверка
	производится в начале каждого часа. 
	Ручная проверка и начисление скора производится в разделе <a href="https://linuxtalks.co/forum/feedback/2057">Наше сообщество.</a>
    </div>
<form:form modelAttribute="form" method="POST" action="register.jsp" id="registerForm">
    <lor:csrf/>
    <form:errors element="div" cssClass="error"/>

  <div class="control-group">
    <label for="nick">Login</label>
    <form:input class="btn btn-selected" path="nick" required="required" size="40" cssErrorClass="error"
                title="<br>Только латинские буквы, цифры и знаки _-,<br>
                 в первом символе только буквы.<br>
                 И не короче 5 символов.<br>"
                pattern="[a-zA-Z][a-zA-Z0-9_-][a-zA-Z0-9_-][a-zA-Z0-9_-][a-zA-Z0-9_-][a-zA-Z0-9_-]*"
                autocapitalize="off"
                autofocus="autofocus" maxlength="<%= Integer.toString(User.MAX_NICK_LENGTH) %>"/>
                <br>
    <form:errors path="nick" element="span" cssClass="error help-inline" for="nick"/><br>
    <div class="help-block">
      мы сохраняем регистр, в котором введён логин
    </div>
  </div>

  <div class="control-group">
    <label for="email">E-mail</label>
    <form:input readonly="${invite!=null}" path="email" type="email" required="required" cssClass="email btn btn-selected" size="40" cssErrorClass="error"/><br>
    <form:errors class="btn btn-selected" path="email" element="span" cssClass="error help-inline" for="email"/><br>
    <div class="help-block" style="max-width:20rem;">
    <ul>Чтобы с гарантией получить письмо, 
    <li>используйте одного из широкоизвестных email-провайдеров.</li>
    <li>На левые почтовые сервера емейлы могут не придти.</li>
    <li>В целях защиты регистрационные письма приходят в дневное время.</li>
    </ul>
    </div>
  </div>

  <div class="control-group">
    <label for="password">Пароль</label>
    <form:password class="btn btn-selected" path="password" size="40" required="required" cssErrorClass="error" minlength="5"/>
    <form:errors class="btn btn-selected" path="password" element="span" cssClass="error help-inline" for="password"/>
  </div>

  <div class="control-group">
    <label for="password2">Подтвердите пароль</label>
    <form:password class="btn btn-selected" path="password2" size="40" required="required" cssErrorClass="error"/>
    <form:errors class="btn btn-selected" path="password2" element="span" cssClass="error help-inline btn btn-selected" for="password"/>
  </div>

  <c:if test="${invite==null}">
    <div class="control-group">
      <lor:captcha/>
    </div>
  </c:if>

  <c:if test="${invite!=null}">
    <input type="hidden" name="invite" value="${fn:escapeXml(invite)}">
  </c:if>

  <c:if test="${permit!=null}">
    <input type="hidden" name="permit" value="${fn:escapeXml(permit)}">
  </c:if>

  <div class="control-group">
    <label for="rules">С
      <a href="/help/rules.md" target="_blank" title="правила откроются в новом окне">правилами</a> ознакомился:
      <form:checkbox class="btn btn-selected" path="rules" id="rules" value="okay" required="required" cssErrorClass="error"/>
      <form:errors path="rules" element="span" cssClass="error help-inline" for="rules"/></label>
  </div>

  <div class="form-actions">
    <button type=submit class="btn btn-primary">Зарегистрироваться</button>
  </div>
</form:form>
<a href="/lostpwd.jsp">Восстановить пароль</a>.
</p>

<jsp:include page="footer.jsp"/>

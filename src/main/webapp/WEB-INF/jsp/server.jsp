<%@ page contentType="text/html; charset=utf-8"%>
<%--
  ~ Copyright 1998-2018 Linux.org.ru
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
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ taglib tagdir="/WEB-INF/tags" prefix="lor" %>

<jsp:include page="/WEB-INF/jsp/head.jsp"/>

<title>О сервере</title>
<jsp:include page="/WEB-INF/jsp/header.jsp"/>

<h1>О проекте</h1>

Проект &laquo;<i>LINUX.ORG.RU: Русская информация об&nbsp;ОС&nbsp;Linux</i>&raquo; был
основан в&nbsp;октябре
1998&nbsp;года. Нашей целью является создание основного информационного ресурса об
операционной системе Linux в&nbsp;России. Мы&nbsp;стараемся обеспечить возможность
обмена различной Linux-ориентированной информацией, последними новостями,
ссылками, документацией и&nbsp;другими ресурсами.

<h1>Наша кнопочка</h1>
Вы можете использовать эту кнопку для ссылки на наш сайт:<br>
<img width=88 height=31 src="/img/button.gif" alt="Кнопка www.linux.org.ru">
  <p>
  и чудо баннер:<br>
  <img src="/img/linux-banner5.gif" alt="www.linux.org.ru" width="468" height="60">
  </p>

<h1>Хостинг</h1>
<p>
  Размещение сервера и&nbsp;подключение к&nbsp;сети Интернет осуществляется компанией
  &laquo;<a href="https://selectel.ru/?ref_code=3dce4333ba" target="_blank">Selectel</a>&raquo;.
</p>
<p>
  Защиту сайта от DDoS-атак осуществляет <a href="http://qrator.net/">QRATOR</a>.
</p>
<p>
  <a href="https://ping-admin.com/uptime/a0005fd81d119564b8eab22d30a83c521169395.html" target="_blank">
    <img src="//images.ping-admin.ru/i/uptime/f56ef6b27e20049339fbfae23ef4e82a1169395_103.gif" width="88" height="31" border="0" alt="Uptime по данным Ping-Admin.Com - сервиса мониторинга доступности сайтов">
  </a>
<h1>Сервер</h1>
<p>
Сервер для сайта предоставлен &laquo;<a href="http://www.ittelo.ru/"target="_blank">ITTelo</a>&raquo;.
</p>

<p>
Конфигурация
</p>
<ul>
  <li>Supermicro 6016T-UF;</li>
  <li>2 x Intel Xeon E5620 12M Cache, 2.40 GHz, 4 ядра;</li>
  <li>48 GB DDR3, ECC, REG;</li>
  <li>2x 1Tb Seagate Constellation ES.3 (RAID1 mdadm);</li>
  <li>2x 240Gb OCZ Trion 1000 (RAID1 with HDD, «write mostly»).</li>
</ul>

<h1>Софт</h1>
  <p>
Мы работаем на:
  </p>
    <ul>
      <li>CentOS 7.x;</li>
      <li>СУБД PostgreSQL 10;</li>
      <li>OpenJDK 11;</li>
      <li>Scala 2.13;</li>
      <li>Apache Tomcat 8.5;</li>
      <li>ActiveMQ 5.11;</li>
      <li>Spring 4.3;</li>
      <li>поиск: Elasticsearch 6.x;</li>
      <li>Nginx 1.14.</li>
    </ul>

<h1>Исходные тексты</h1>

  Исходные тексты  <a href="https://github.com/maxcom/lorsource">доступны</a> под лицензией Apache License 2.0.
  <h2>Entypo font</h2>
  На сайте используется иконочный шрифт Entypo, Copyright (C) 2012 by Daniel Bruce,
  <a href="http://www.entypo.com">http://www.entypo.com</a>. Шрифт с нужным нам набором символов
  сгенерирован при помощи <a href="http://fontello.com/">fontello.com</a>.

  <h2>BSD Daemon</h2>
  Права на изображение <a href="https://www.mckusick.com/beastie/">BSD Daemon</a>
  принадлежат <a href="https://www.mckusick.com/beastie/mainpage/copyright.html">Marshall Kirk McKusick</a>.

<h1>Наша команда</h1>
Проект реализован и&nbsp;развивается исключительно в&nbsp;свободное время авторов.
  <ul>
  <li><a href="/people/maxcom/profile">Максим Валянский</a> (maxcom)&nbsp;&#8212; <i>координатор
  проекта</i>:
  разработка, поддержка, дизайн, новости, информационное наполнение;

  <li><a href="/people/green/profile">Олег Дрокин</a> (green)&nbsp;&#8212; администрирование сервера, железо;
  <li><a href="/people/Slavaz/profile">Вячеслав Занько</a> (Slavaz)&nbsp;&#8212; разработка, поддержка.
  </ul>

  Модераторы:
  <ul>
    <c:forEach var="user" items="${moderators}">
      <li>
        <c:choose>
            <c:when test="${not empty user.name}">
                <c:out escapeXml="true" value="${user.name}"/> (<lor:user user="${user}" link="true"/>)
            </c:when>
            <c:otherwise>
                <lor:user user="${user}" link="true"/>
            </c:otherwise>
        </c:choose>
      </li>
    </c:forEach>
  </ul>

  Корректоры новостей:
  <ul>
    <c:forEach var="user" items="${correctors}">
      <li>
        <c:choose>
            <c:when test="${not empty user.name}">
                <c:out escapeXml="true" value="${user.name}"/> (<lor:user user="${user}" link="true"/>)
            </c:when>
            <c:otherwise>
                <lor:user user="${user}" link="true"/>
            </c:otherwise>
        </c:choose>
      </li>
    </c:forEach>
  </ul>

<jsp:include page="/WEB-INF/jsp/footer.jsp"/>

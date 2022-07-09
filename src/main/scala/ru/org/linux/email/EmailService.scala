/*
 * Copyright 1998-2022 Linux.org.ru
 *    Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 *
 *        http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
 */

package ru.org.linux.email

import akka.actor.ActorRef
import com.google.common.net.HttpHeaders
import com.typesafe.scalalogging.StrictLogging
import org.joda.time.DateTime
import org.springframework.beans.factory.annotation.Qualifier
import org.springframework.stereotype.Service
import ru.org.linux.auth.AuthUtil
import ru.org.linux.exception.ExceptionMailingActor
import ru.org.linux.site.DateFormats
import ru.org.linux.spring.SiteConfig
import ru.org.linux.user.User
import ru.org.linux.util.LorHttpUtils

import java.io.{PrintWriter, StringWriter}
import java.net.URLEncoder
import java.util.{Date, Properties}
import javax.mail.internet.{InternetAddress, MimeMessage}
import javax.mail._
import javax.servlet.http.HttpServletRequest
import scala.jdk.CollectionConverters._

@Service
class EmailService(siteConfig: SiteConfig, @Qualifier("exceptionMailingActor") exceptionMailingActor: ActorRef)
  extends StrictLogging {
  def sendRegistrationEmail(nick: String, email: String, isNew: Boolean): Unit = {
    val regcode = User.getActivationCode(siteConfig.getSecret, nick, email)

    val text = new StringBuilder
    text.append(
      """
        |Здравствуйте!
        |
      """.stripMargin)

    if (isNew) {
      text.append("На форуме по адресу https://linuxtalks.co/ появилась регистрационная запись,\n")
    } else {
      text.append("На форуме по адресу https://linuxtalks.co/ была изменена регистрационная запись,\n")
    }

    text.append(
      s"""
         |в которой был указан ваш электронный адрес (e-mail).
         |
         |При заполнении регистрационной формы было указано следующее имя пользователя: '$nick'
         |
         |Если вы не понимаете, о чем идет речь - просто проигнорируйте это сообщение!
         |
       """.stripMargin)

    if (isNew) {
      text.append(
        """
          |Если же именно вы решили зарегистрироваться на форуме по адресу https://linuxtalks.co/,
          |то вам следует подтвердить свою регистрацию и тем самым активировать вашу учетную запись.
          |
        """.stripMargin)
    } else {
      text.append(
        """
          |Если же именно вы решили изменить свою регистрационную запись https://linuxtalks.co/,
          |то вам следует подтвердить свое изменение.
          |
        """.stripMargin)
    }

    text.append(
      s"""
         |Для активации перейдите по ссылке:
         |
         |https://linuxtalks.co/activate?nick=$nick&activation=${URLEncoder.encode(regcode, "utf-8")}
         |
         |(код активации: $regcode)
         |
         |Благодарим за регистрацию!
         |
       """.stripMargin)

    sendRegistrationMail(email, text.toString())
  }

  def sendInviteEmail(inviteUser: User, email: String, inviteCode: String, validUntil: DateTime): Unit = {
    val text =
      s"""
         |Здравствуйте!
         |
         |Участник https://linuxtalks.co/, ${inviteUser.getNick} (https://linuxtalks.co/people/${inviteUser.getNick}/profile),
         |пригласил вас зарегистрироваться на форуме.\n
         |
         |Если вы не понимаете, о чем идет речь - просто проигнорируйте это сообщение!
         |
         |Для регистрации перейдите по ссылке:
         |
         |https://linuxtalks.co/register.jsp?invite=${URLEncoder.encode(inviteCode, "utf-8")}
         |
         |Эта ссылка позволяет зарегистрировать только одну учетную запись. Ссылка действует
         |до ${DateFormats.dateTime(validUntil.toDate, SiteConfig.DEFAULT_TIMEZONE)}.
         |
         |До встречи!
         |
       """.stripMargin

    sendRegistrationMail(email, text)
  }

  private def sendRegistrationMail(email: String, text: String): Unit = {
    val emailMessage = EmailService.createMessage(siteConfig)
    emailMessage.setFrom(new InternetAddress("no-reply@linuxtalks.co"))
    emailMessage.addRecipient(Message.RecipientType.TO, new InternetAddress(email))
    emailMessage.setSubject("Регистрация на linuxtalks.co", "UTF-8")
    emailMessage.setSentDate(new Date)
    emailMessage.setText(text, "UTF-8")
    try {
      Transport.send(emailMessage)
    } catch {
      case e:Exception  => print(e.getMessage)
    }

    logger.info(s"Sent new/update registration email to $email")
  }

  /**
    * Отсылка E-mail администраторам.
    *
    * @param request   данные запроса от web-клиента
    * @param exception исключение
    * @return Строку, содержащую состояние отсылки письма
    */
  def sendExceptionReport(request: HttpServletRequest, exception: Exception): String = {
    val text = new StringBuilder

    if (exception.getMessage == null) {
      text.append(exception.getClass.getName)
    } else {
      text.append(exception.getMessage)
    }

    text.append("\n\n")
    val attributeUrl = request.getAttribute("javax.servlet.error.request_uri")
    if (attributeUrl != null) {
      text.append(s"Attribute URL: $attributeUrl\n")
    }
    val forwardUrl = request.getAttribute("javax.servlet.forward.request_uri")
    if (forwardUrl != null) {
      text.append(s"Forward URL: $forwardUrl\n")
    }
    val mainUrl = siteConfig.getSecureUrlWithoutSlash
    text.append(s"${request.getMethod}: $mainUrl${request.getServletPath}")
    if (request.getQueryString != null) {
      text.append(s"?${request.getQueryString}")
    }
    text.append('\n')
    text.append(s"IP: ${LorHttpUtils.getRequestIp(request)}\n")

    if (AuthUtil.getNick != null) {
      text.append(s"Current user: ${AuthUtil.getNick}\n")
    }

    text.append("Headers: ")

    for (name <- request.getHeaderNames.asScala if !name.equalsIgnoreCase(HttpHeaders.COOKIE)) {
      text.append(s"\n         $name: ${request.getHeader(name)}")
    }

    text.append("\n\n")

    val exceptionStackTrace = new StringWriter
    exception.printStackTrace(new PrintWriter(exceptionStackTrace))
    text.append(exceptionStackTrace.toString)

    exceptionMailingActor ! ExceptionMailingActor.Report(exception.getClass, text.toString())

    "Произошла непредвиденная ошибка. Администраторы получили об этом сигнал."
  }
}

object EmailService {
  def createMessage(siteConfig: SiteConfig) = {
    val props = new Properties
    props.put("mail.smtp.host", siteConfig.getSmtpHost);
    props.put("mail.smtp.port", siteConfig.getSmtpPort);
    props.put("mail.smtp.auth", siteConfig.getSmtpLogin != null);
    props.put("mail.smtp.ssl.enable", siteConfig.getSmtpLogin != null);
    val authenticator = new Authenticator() {
      override def getPasswordAuthentication: PasswordAuthentication = {
        if (siteConfig.getSmtpLogin != null)  new PasswordAuthentication(siteConfig.getSmtpLogin, siteConfig.getSmtpPass) else null;
      }
    }
    new MimeMessage(Session.getDefaultInstance(props, authenticator))
  }
}

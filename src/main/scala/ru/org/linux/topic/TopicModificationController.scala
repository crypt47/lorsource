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

package ru.org.linux.topic

import com.typesafe.scalalogging.StrictLogging
import javax.servlet.ServletRequest
import javax.servlet.http.HttpServletRequest
import org.springframework.stereotype.Controller
import org.springframework.web.bind.annotation.{RequestMapping, RequestMethod, RequestParam}
import org.springframework.web.servlet.ModelAndView
import org.springframework.web.servlet.view.RedirectView
import ru.org.linux.auth.AccessViolationException
import ru.org.linux.group.GroupDao
import ru.org.linux.markup.MessageTextService
import ru.org.linux.search.SearchQueueSender
import ru.org.linux.section.{Section, SectionService}
import ru.org.linux.site.Template
import ru.org.linux.spring.dao.MsgbaseDao
import ru.org.linux.user.{UserDao, UserErrorException}

import scala.jdk.CollectionConverters._
import scala.compat.java8.OptionConverters._

@Controller
class TopicModificationController(prepareService: TopicPrepareService, messageDao: TopicDao,
                                  sectionService: SectionService, groupDao: GroupDao,
                                  userDao: UserDao, searchQueueSender: SearchQueueSender,
                                  msgbaseDao: MsgbaseDao, textService: MessageTextService) extends StrictLogging {

  @RequestMapping(value = Array("/setpostscore.jsp"), method = Array(RequestMethod.GET))
  def showForm(request: ServletRequest, @RequestParam msgid: Int): ModelAndView = {
    val tmpl = Template.getTemplate(request)

    if (!tmpl.isModeratorSession) {
      throw new AccessViolationException("Not moderator")
    }

    val message = messageDao.getById(msgid)

    new ModelAndView("setpostscore", Map(
      "message" -> message,
      "group" -> groupDao.getGroup(message.getGroupId)
    ).asJava)
  }

  @RequestMapping(value = Array("/setpostscore.jsp"), method = Array(RequestMethod.POST))
  def modifyTopic(request: ServletRequest,
                  @RequestParam msgid: Int,
                  @RequestParam postscore: Int,
                  @RequestParam(defaultValue = "false") sticky: Boolean,
                  @RequestParam(defaultValue = "false") notop: Boolean): ModelAndView = {
    val tmpl = Template.getTemplate(request)

    if (!tmpl.isModeratorSession) {
      throw new AccessViolationException("Not moderator")
    }

    if (postscore < TopicPermissionService.POSTSCORE_UNRESTRICTED) {
      throw new UserErrorException(s"invalid postscore $postscore")
    }

    if (postscore > TopicPermissionService.POSTSCORE_UNRESTRICTED &&
      postscore < TopicPermissionService.POSTSCORE_REGISTERED_ONLY) {
      throw new UserErrorException(s"invalid postscore $postscore")
    }

    if (postscore > TopicPermissionService.POSTSCORE_HIDE_COMMENTS) {
      throw new UserErrorException(s"invalid postscore $postscore")
    }

    val user = tmpl.getCurrentUser

    user.checkCommit()

    val topic = messageDao.getById(msgid)

    messageDao.setTopicOptions(topic, postscore, sticky, notop)

    val out = new StringBuilder
    if (topic.getPostscore != postscore) {
      out.append("Установлен новый уровень записи: ").append(postScoreInfoFull(postscore)).append("<br>")
      logger.info(s"Установлен новый уровень записи $postscore для $msgid пользователем ${user.getNick}")

      searchQueueSender.updateMessage(topic.getId, true)
    }

    if (topic.isSticky != sticky) {
      out.append("Новое значение sticky: ").append(sticky).append("<br>")
      logger.info(s"Новое значение sticky: $sticky")
    }

    if (topic.isNotop != notop) {
      out.append("Новое значение notop: ").append(notop).append("<br>")
      logger.info(s"Новое значение notop: $notop")
    }

    new ModelAndView("action-done", Map (
      "message" -> "Данные изменены",
      "bigMessage" -> out.toString,
      "link" -> topic.getLink
    ).asJava)
  }

  @RequestMapping(value = Array("/mt.jsp"), method = Array(RequestMethod.POST))
  def moveTopic(request: ServletRequest, @RequestParam msgid: Int, @RequestParam("moveto") newgr: Int): RedirectView = {
    val tmpl = Template.getTemplate(request)

    if (!tmpl.isModeratorSession) {
      throw new AccessViolationException("Not moderator")
    }

    val msg = messageDao.getById(msgid)
    if (msg.isDeleted) {
      throw new AccessViolationException("Сообщение удалено")
    }

    val newGrp = groupDao.getGroup(newgr)

    if (msg.getGroupId != newGrp.getId) {
      val moveInfo = if (!newGrp.isLinksAllowed) {
        val moveFrom = msg.getGroupUrl
        val linktext = msg.getLinktext
        val url = msg.getUrl

        val markup = msgbaseDao.getMessageText(msg.getId).markup

        Some(textService.moveInfo(markup, url, linktext, tmpl.getCurrentUser, moveFrom))
      } else {
        None
      }

      messageDao.moveTopic(msg, newGrp, moveInfo.asJava)
      logger.info(s"topic ${msg.getId} moved by ${tmpl.getCurrentUser.getNick} from news/forum ${msg.getGroupUrl} to forum ${newGrp.getTitle}")
    }

    searchQueueSender.updateMessage(msg.getId, true)

    new RedirectView(TopicLinkBuilder.baseLink(msg).forceLastmod.build)
  }

  @RequestMapping(value = Array("/mt.jsp"), method = Array(RequestMethod.GET))
  def moveTopicFormForum(request: ServletRequest, @RequestParam msgid: Int): ModelAndView = {
    val tmpl = Template.getTemplate(request)

    if (!tmpl.isModeratorSession) {
      throw new AccessViolationException("Not authorized")
    }

    val topic = messageDao.getById(msgid)


    new ModelAndView("mtn", Map (
      "message" -> topic,
      "groups" -> groupDao.getAllForumGroups,
      "sections" -> sectionService.idToSection.asJava,
      "author" -> userDao.getUserCached(topic.getAuthorUserId)
    ).asJava)
  }

  @RequestMapping(value = Array("/mtn.jsp"), method = Array(RequestMethod.GET))
  @throws[Exception]
  def moveTopicForm(request: ServletRequest, @RequestParam msgid: Int): ModelAndView = {
    val tmpl = Template.getTemplate(request)

    if (!tmpl.isModeratorSession) {
      throw new AccessViolationException("Not authorized")
    }

    val topic = messageDao.getById(msgid)
    val section = sectionService.getSection(topic.getSectionId)

    new ModelAndView("mtn", Map(
      "message" -> topic,
      "groups" -> groupDao.getGroups(section),
      "author" -> userDao.getUserCached(topic.getAuthorUserId)
    ).asJava)
  }

  @RequestMapping(value = Array("/uncommit.jsp"), method = Array(RequestMethod.GET))
  def uncommitForm(request: HttpServletRequest, @RequestParam msgid: Int): ModelAndView = {
    val tmpl = Template.getTemplate(request)

    if (!tmpl.isModeratorSession) {
      throw new AccessViolationException("Not authorized")
    }

    val message = messageDao.getById(msgid)

    checkUncommitable(message)

    new ModelAndView("uncommit", Map(
      "message" -> message,
      "preparedMessage" -> prepareService.prepareTopic(message, tmpl.getCurrentUser)
    ).asJava)
  }

  @RequestMapping(value = Array("/uncommit.jsp"), method = Array(RequestMethod.POST))
  def uncommit(request: HttpServletRequest, @RequestParam msgid: Int): ModelAndView = {
    val tmpl = Template.getTemplate(request)

    if (!tmpl.isModeratorSession) {
      throw new AccessViolationException("Not authorized")
    }

    val message = messageDao.getById(msgid)

    checkUncommitable(message)

    messageDao.uncommit(message)

    searchQueueSender.updateMessage(message.getId, true)

    logger.info("Отменено подтверждение сообщения " + msgid + " пользователем " + tmpl.getNick)

    new ModelAndView("action-done", "message", "Подтверждение отменено")
  }

  private def checkUncommitable(message: Topic):Unit = {
    if (message.isExpired) {
      throw new AccessViolationException("нельзя восстанавливать устаревшие сообщения")
    }
    if (message.isDeleted) {
      throw new AccessViolationException("сообщение удалено")
    }
    if (!message.isCommited) {
      throw new AccessViolationException("сообщение не подтверждено")
    }
  }

  private def postScoreInfoFull(postscore: Int): String = {
    val info = TopicPermissionService.getPostScoreInfo(postscore)

    if (info.isEmpty) {
      "без ограничений"
    } else {
      info
    }
  }
}
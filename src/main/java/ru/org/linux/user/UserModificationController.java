/*
 * Copyright 1998-2017 Linux.org.ru
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

package ru.org.linux.user;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.WebDataBinder;
import org.springframework.web.bind.annotation.InitBinder;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.ModelAndView;
import org.springframework.web.servlet.view.RedirectView;
import ru.org.linux.auth.AccessViolationException;
import ru.org.linux.comment.CommentDeleteService;
import ru.org.linux.comment.DeleteCommentResult;
import ru.org.linux.search.SearchQueueSender;
import ru.org.linux.site.Template;

import javax.servlet.ServletRequest;
import javax.servlet.http.HttpServletRequest;
import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.sql.Timestamp;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.Random;

@Controller
public class UserModificationController {
  private static final Logger logger = LoggerFactory.getLogger(UserModificationController.class);

  @Autowired
  private SearchQueueSender searchQueueSender;

  @Autowired
  private UserDao userDao;

  @Autowired
  private CommentDeleteService commentService;

  /**
   * Возвращает объект User модератора, если текущая сессия не модераторская, тогда исключение
   * @param request текущий http запрос
   * @return текущий модератор
   */
  private static User getModerator(HttpServletRequest request) {
    Template tmpl = Template.getTemplate(request);
    if (!tmpl.isModeratorSession()) {
      throw new AccessViolationException("Not moderator");
    }
    return tmpl.getCurrentUser();
  }

  /**
   * Контроллер блокировки пользователя
   * @param request http запрос
   * @param user блокируемый пользователь
   * @param reason причина блокировки
   * @return возвращаемся в профиль
   * @throws Exception обычно если текущий пользователь не модератор или блокируемого пользователя
   * нельзя блокировать
   */
  @RequestMapping(value = "/usermod.jsp", method = RequestMethod.POST, params = "action=block")
  public ModelAndView blockUser(
      HttpServletRequest request,
      @RequestParam("id") User user,
      @RequestParam(value = "reason", required = false) String reason
  ) throws Exception {
    User moderator = getModerator(request);
    if (!user.isBlockable() && !moderator.isAdministrator()) {
      throw new AccessViolationException("Пользователя " + user.getNick() + " нельзя заблокировать");
    }

    if (user.isBlocked()) {
      throw new UserErrorException("Пользователь уже блокирован");
    }

    userDao.block(user, moderator, reason);
    logger.info("User " + user.getNick() + " blocked by " + moderator.getNick());
    return redirectToProfile(user);
  }

  /**
   * Выставляем score=50 для пользователей у которых score меньше
   *
   * @param request http запрос
   * @param user кому ставим score
   * @return возвращаемся в профиль
   * @throws Exception обычно если текущий пользователь не модератор или пользователь блокирован
   */
  @RequestMapping(value = "/usermod.jsp", method = RequestMethod.POST, params = "action=score50")
  public ModelAndView score50(
          HttpServletRequest request,
          @RequestParam("id") User user
  ) throws Exception {
    User moderator = getModerator(request);
    if (user.isBlocked() || user.isAnonymous()) {
      throw new AccessViolationException("Нельзя выставить score=50 пользователю " + user.getNick());
    }

    userDao.score50(user, moderator);

    return redirectToProfile(user);
  }

  /**
   * Контроллер разблокировки пользователя
   * @param request http запрос
   * @param user разблокируемый пользователь
   * @return возвращаемся в профиль
   * @throws Exception обычно если текущий пользователь не модератор или пользователя нельзя разблокировать
   */
  @RequestMapping(value = "/usermod.jsp", method = RequestMethod.POST, params = "action=unblock")
  public ModelAndView unblockUser(
      HttpServletRequest request,
      @RequestParam("id") User user
  ) throws Exception {

    User moderator = getModerator(request);
    if (!user.isBlockable() && !moderator.isAdministrator()) {
      throw new AccessViolationException("Пользователя " + user.getNick() + " нельзя разблокировать");
    }
    userDao.unblock(user, moderator);
    logger.info("User " + user.getNick() + " unblocked by " + moderator.getNick());
    return redirectToProfile(user);
  }

  private static ModelAndView redirectToProfile(User user) throws UnsupportedEncodingException{
    return new ModelAndView(new RedirectView(getNoCacheLinkToProfile(user)));
  }

  private static String getNoCacheLinkToProfile(User user) {
    Random random = new Random();
    return "/people/" + URLEncoder.encode(user.getNick(), StandardCharsets.UTF_8) + "/profile?nocache=" + random.nextInt();
  }

  /**
   * Контроллер блокирования и полного удаления комментариев и топиков пользователя
   * @param request http запрос
   * @param user блокируемый пользователь
   * @return возвращаемся в профиль
   */
  @RequestMapping(value = "/usermod.jsp", method = RequestMethod.POST, params = "action=block-n-delete-comments")
  public ModelAndView blockAndMassiveDeleteCommentUser(
      HttpServletRequest request,
      @RequestParam("id") User user,
      @RequestParam(value = "reason", required = false) String reason
  ) {
    User moderator = getModerator(request);
    if (!user.isBlockable() && !moderator.isAdministrator()) {
      throw new AccessViolationException("Пользователя " + user.getNick() + " нельзя заблокировать");
    }

    if (user.isBlocked()) {
      throw new UserErrorException("Пользователь уже блокирован");
    }

    Map<String, Object> params = new HashMap<>();
    params.put("message", "Удалено");
    DeleteCommentResult deleteCommentResult = commentService.deleteAllCommentsAndBlock(user, moderator, reason);

    logger.info("User " + user.getNick() + " blocked by " + moderator.getNick());

    params.put("bigMessage",
            "Удалено комментариев: "+deleteCommentResult.getDeletedCommentIds().size()+"<br>"+
            "Удалено тем: "+deleteCommentResult.getDeletedTopicIds().size()
    );

    for (int topicId : deleteCommentResult.getDeletedTopicIds()) {
      searchQueueSender.updateMessage(topicId, true);
    }

    searchQueueSender.updateComment(deleteCommentResult.getDeletedCommentIds());

    return new ModelAndView("action-done", params);
  }

  /**
   * Контроллер смена признака корректора
   * @param request http запрос
   * @param user блокируемый пользователь
   * @return возвращаемся в профиль
   * @throws Exception обычно если текущий пользователь не модератор или пользователя нельзя сделать корректором
   */
  @RequestMapping(value = "/usermod.jsp", method = RequestMethod.POST, params = "action=toggle_corrector")
  public ModelAndView toggleUserCorrector(
      HttpServletRequest request,
      @RequestParam("id") User user
  ) throws Exception {
    User moderator = getModerator(request);
    if (user.getScore()<User.CORRECTOR_SCORE) {
      throw new AccessViolationException("Пользователя " + user.getNick() + " нельзя сделать корректором");
    }
    userDao.toggleCorrector(user, moderator);
    logger.info("Toggle corrector " + user.getNick() + " by " + moderator.getNick());

    return redirectToProfile(user);
  }

  /**
   * Сброс пароля пользователю
   * @param request http запрос
   * @param user пользователь которому сбрасываем пароль
   * @return сообщение о успешности сброса
   * @throws Exception при ошибке или отсутствии прав
   */
  @RequestMapping(value = "/usermod.jsp", method = RequestMethod.POST, params = "action=reset-password")
  public ModelAndView resetPassword(
      HttpServletRequest request,
      @RequestParam("id") User user
  ) throws Exception {
    User moderator = getModerator(request);

    if (user.isModerator() || user.isAnonymous()) {
      throw new AccessViolationException("Пользователю " + user.getNick() + " нельзя сбросить пароль");
    }

    userDao.resetPassword(user, moderator);

    logger.info("Пароль "+user.getNick()+" сброшен модератором "+moderator.getNick());

    ModelAndView mv = new ModelAndView("action-done");
    mv.getModel().put("link", getNoCacheLinkToProfile(user));
    mv.getModel().put("message", "Пароль сброшен");
    return mv;
  }
  
  /**
   * Контроллер отчистки дополнительной информации в профиле
   * @param request http запрос
   * @param user блокируемый пользователь
   * @return возвращаемся в профиль
   * @throws Exception обычно если текущий пользователь не модератор или нельзя трогать дополнительные сведения
   */
  @RequestMapping(value = "/usermod.jsp", method = RequestMethod.POST, params = "action=remove_userinfo")
  public ModelAndView removeUserInfo(
      HttpServletRequest request,
      @RequestParam("id") User user
  ) throws Exception {
    User moderator = getModerator(request);
    if (user.isModerator()) {
      throw new AccessViolationException("Пользователю " + user.getNick() + " нельзя удалить сведения");
    }
    userDao.removeUserInfo(user, moderator);
    logger.info("Clearing " + user.getNick() + " userinfo by " + moderator.getNick());

    return redirectToProfile(user);
  }

  @RequestMapping(value="/remove-userpic.jsp", method= RequestMethod.POST)
  public ModelAndView removeUserpic(
    ServletRequest request,
    @RequestParam("id") User user
  ) throws Exception {
    Template tmpl = Template.getTemplate(request);

    if (!tmpl.isSessionAuthorized()) {
      throw new AccessViolationException("Not autorized");
    }

    User currentUser = tmpl.getCurrentUser();

    // Не модератор не может удалять чужие аватары
    if (!tmpl.isModeratorSession() && currentUser.getId()!=user.getId()) {
      throw new AccessViolationException("Not permitted");
    }

    if (userDao.resetUserpic(user, currentUser)) {
      logger.info("Clearing " + user.getNick() + " userpic by " + currentUser.getNick());
    } else {
      logger.debug("SKIP Clearing " + user.getNick() + " userpic by " + currentUser.getNick());
    }

    return redirectToProfile(user);
  }

  /**
   * Контроллер заморозки и разморозки пользователя
   * @param request http запрос
   * @param user блокируемый пользователь
   * @param reason причина заморозки, общедоступна в дальнейшем
   * @param shift отсчёт времени от текущей точки, может быть отрицательным, в
   *              в результате даёт until, отрицательное значение используется
   *              для разморозки
   * @return возвращаемся в профиль
   * @throws Exception обычно если текущий пользователь не модератор или пользователя нельзя сделать корректором
   */
  @RequestMapping(value = "/usermod.jsp", method = RequestMethod.POST, params = "action=freeze")
  public ModelAndView freezeUser(
      HttpServletRequest request,
      @RequestParam(name = "id", required = true) User user,
      @RequestParam(name = "reason", required = true) String reason,
      @RequestParam(name = "shift", required = true) String shift
  ) throws Exception {

    if (reason.length() > 255) {
      throw new UserErrorException("Причина слишком длиная, максимум 255 байт");
    }

    User moderator = getModerator(request);
    Timestamp until = getUntil(shift);


    if (!user.isBlockable() && !moderator.isAdministrator()) {
      throw new AccessViolationException("Пользователя " + user.getNick() + " нельзя заморозить");
    }

    if (user.isBlocked()) {
      throw new UserErrorException("Пользователь блокирован, его нельзя заморозить");
    }

    userDao.freezeUser(user, moderator, reason, until);
    logger.info("Freeze " + user.getNick() + " by " + moderator.getNick() + " until " + until);

    return redirectToProfile(user);
  }

  // get 'now', add the duration and returns result;
  // the duration can be negative
  private static Timestamp getUntil(String shift) {
    Duration  d   = Duration.parse(shift);
    Timestamp now = new Timestamp(System.currentTimeMillis());
    now.setTime(now.getTime() + d.toMillis());
    return now;
  }


  @InitBinder
  public void initBinder(WebDataBinder binder) {
    binder.registerCustomEditor(User.class, new UserIdPropertyEditor(userDao));
  }
}

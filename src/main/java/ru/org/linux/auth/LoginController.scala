/*
 * Copyright 1998-2021 Linux.org.ru
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
package ru.org.linux.auth

import java.util.concurrent.CompletionStage
import akka.actor.ActorSystem
import com.typesafe.scalalogging.StrictLogging

import javax.servlet.http.{Cookie, HttpServletRequest, HttpServletResponse}
import org.springframework.security.authentication.{AuthenticationManager, BadCredentialsException, LockedException, UsernamePasswordAuthenticationToken}
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.security.core.userdetails.{UserDetailsService, UsernameNotFoundException}
import org.springframework.security.web.authentication.logout.SecurityContextLogoutHandler
import org.springframework.stereotype.Controller
import org.springframework.web.bind.annotation.{RequestMapping, RequestMethod, RequestParam, ResponseBody}
import org.springframework.web.servlet.ModelAndView
import org.springframework.web.servlet.view.RedirectView
import ru.org.linux.site.{PublicApi, Template}
import ru.org.linux.user.UserDao
import ru.org.linux.util.LorHttpUtils

import scala.compat.java8.FutureConverters._
import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.Promise
import scala.concurrent.duration._
import scala.util.{Random, Try}

@PublicApi
case class LoginStatus(success: Boolean, username: String) {
  def isLoggedIn: Boolean = success

  def getUsername: String = username
}

@Controller
class LoginController(userDao: UserDao, userDetailsService: UserDetailsService,
                      rememberMeServices: GenerationBasedTokenRememberMeServices,
                      authenticationManager: AuthenticationManager, actorSystem: ActorSystem) extends StrictLogging {
  @RequestMapping(value = Array("/login_process"), method = Array(RequestMethod.POST))
  def loginProcess(@RequestParam("nick") username: String, @RequestParam("passwd") password: String,
                   request: HttpServletRequest, response: HttpServletResponse): CompletionStage[ModelAndView] = {
    val token = new UsernamePasswordAuthenticationToken(username, password)
    try {
      val details = userDetailsService.loadUserByUsername(username).asInstanceOf[UserDetailsImpl]
      token.setDetails(details)
      val auth = authenticationManager.authenticate(token)
      val userDetails = auth.getDetails.asInstanceOf[UserDetailsImpl]

      if (!userDetails.getUser.isActivated) {
        delayResponse { new ModelAndView(new RedirectView("/login.jsp?error=not_activated")) }
      } else {
        SecurityContextHolder.getContext.setAuthentication(auth)
        rememberMeServices.loginSuccess(request, response, auth)

        delayResponse {
          AuthUtil.updateLastLogin(auth, userDao)
          new ModelAndView(new RedirectView("/"))
        }
      }
    } catch {
      case e@(_: LockedException | _: BadCredentialsException | _: UsernameNotFoundException) =>
        logger.warn("Login of " + username + " failed; remote IP: " + LorHttpUtils.getRequestIp(request) + "; " + e.toString)

        delayResponse {
          new ModelAndView(new RedirectView("/login.jsp?error=true"))
        }
    }
  }

  @RequestMapping(value = Array("/ajax_login_process"), method = Array(RequestMethod.POST))
  @ResponseBody
  def loginAjax(@RequestParam("nick") username: String, @RequestParam("passwd") password: String,
                request: HttpServletRequest, response: HttpServletResponse): CompletionStage[LoginStatus] = {
    val token = new UsernamePasswordAuthenticationToken(username, password)
    try {
      val details = userDetailsService.loadUserByUsername(username).asInstanceOf[UserDetailsImpl]
      token.setDetails(details)
      val auth = authenticationManager.authenticate(token)
      val userDetails = auth.getDetails.asInstanceOf[UserDetailsImpl]

      if (!userDetails.getUser.isActivated) {
        delayResponse { LoginStatus(success = false, "User not activated") }
      } else {
        SecurityContextHolder.getContext.setAuthentication(auth)
        rememberMeServices.loginSuccess(request, response, auth)

        delayResponse {
          AuthUtil.updateLastLogin(auth, userDao)
          LoginStatus(auth.isAuthenticated, auth.getName)
        }
      }
    } catch {
      case e@(_: LockedException | _: BadCredentialsException | _: UsernameNotFoundException) =>
        logger.warn("Login of " + username + " failed; remote IP: " + LorHttpUtils.getRequestIp(request) + "; " + e.toString)
        delayResponse { LoginStatus(success = false, "Bad credentials") }
    }
  }

  @RequestMapping(value = Array("/logout"), method = Array(RequestMethod.POST))
  def logout(request: HttpServletRequest, response: HttpServletResponse): ModelAndView = {
    val auth = SecurityContextHolder.getContext.getAuthentication
    if (auth != null) new SecurityContextLogoutHandler().logout(request, response, auth)
    val cookie = new Cookie("remember_me", null)
    cookie.setMaxAge(0)
    cookie.setPath("/")
    response.addCookie(cookie)
    new ModelAndView(new RedirectView("/login.jsp"))
  }

  @RequestMapping(value = Array("/logout_all_sessions"), method = Array(RequestMethod.POST))
  def logoutAllDevices(request: HttpServletRequest, response: HttpServletResponse): ModelAndView = {
    if (AuthUtil.isSessionAuthorized) userDao.unloginAllSessions(Template.getTemplate(request).getCurrentUser)
    logout(request, response)
  }

  @RequestMapping(value = Array("/logout", "/logout_all_sessions"), method = Array(RequestMethod.GET))
  def logoutLink: ModelAndView =
    if (AuthUtil.isSessionAuthorized)
      new ModelAndView(new RedirectView("/people/" + AuthUtil.getNick + "/profile"))
    else
      new ModelAndView(new RedirectView("/login.jsp"))

  @RequestMapping(value = Array("/login.jsp"), method = Array(RequestMethod.GET))
  def loginForm = new ModelAndView("login-form")

  private def delayResponse[T](resp : => T): CompletionStage[T] = {
    val r = Random.nextInt(2000) + 1000 // 1 to 3 seconds

    val p = Promise[T]()

    actorSystem.scheduler.scheduleOnce(r.millis) {
      p.complete(Try(resp))
    }

    p.future.toJava
  }
}
package ru.org.linux.user;


import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import ru.org.linux.email.EmailService;
import ru.org.linux.spring.SiteConfig;

import java.util.List;
import java.util.concurrent.TimeUnit;

@Service
public class RegistrationService {
    private static final Logger logger = LoggerFactory.getLogger(RegistrationService.class);

    private final RegistrationLogDao registrationLogDao;
    private final EmailService emailService;

    private final SiteConfig siteConfig;

    @Autowired
    public RegistrationService(RegistrationLogDao registrationLogDao, EmailService emailService, SiteConfig siteConfig) {
        this.registrationLogDao = registrationLogDao;
        this.emailService = emailService;
        this.siteConfig = siteConfig;
    }

    @Scheduled(fixedRate = 1, timeUnit = TimeUnit.MINUTES)
    public void checkPendingRegistrations() {
        List<RegistrationLogItem> pendingRegistrations = registrationLogDao.getPendingRegistrations();
        logger.info("There are currently {} pending registrations", pendingRegistrations.size());
        for (RegistrationLogItem pendingRegistration : pendingRegistrations) {
            if(canSend()) {
                emailService.sendRegistrationEmail(pendingRegistration.getNick(), pendingRegistration.getEmail(), true);
                registrationLogDao.recordMailSent(pendingRegistration.getUserId());
            }
        }
    }

    private boolean canSend() {
        int sentEmailsLastHour = registrationLogDao.getSentEmailsLastHour();
        long minutesSinceLastSentEmail = registrationLogDao.getMinutesSinceLastSentEmail();
        boolean maxRegistrationsPerHourBreached = sentEmailsLastHour <= siteConfig.getMaxRegistrationsPerHour();
        boolean intervalBetweenSendingNotReached = minutesSinceLastSentEmail >= sentEmailsLastHour * siteConfig.getRegistrationInterval();
        logger.info("Checking sending registration email conditions: max registrations limit: {}, interval between sending : {} ", maxRegistrationsPerHourBreached, intervalBetweenSendingNotReached);
        return maxRegistrationsPerHourBreached && intervalBetweenSendingNotReached;
    }
}

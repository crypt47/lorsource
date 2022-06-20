package ru.org.linux.user;

import java.time.LocalDateTime;

public class RegistrationLogItem {
    private int id;
    private int userId;
    private String nick;
    private String email;
    private String activationCode;
    private LocalDateTime registrationTimestamp;
    private LocalDateTime mailSentTimestamp;

    public int getId() {
        return id;
    }

    public int getUserId() {
        return userId;
    }

    public String getActivationCode() {
        return activationCode;
    }

    public LocalDateTime getRegistrationTimestamp() {
        return registrationTimestamp;
    }

    public LocalDateTime getMailSentTimestamp() {
        return mailSentTimestamp;
    }

    public void setId(int id) {
        this.id = id;
    }

    public void setUserId(int userId) {
        this.userId = userId;
    }

    public void setActivationCode(String activationCode) {
        this.activationCode = activationCode;
    }

    public void setRegistrationTimestamp(LocalDateTime registrationTimestamp) {
        this.registrationTimestamp = registrationTimestamp;
    }

    public void setMailSentTimestamp(LocalDateTime mailSentTimestamp) {
        this.mailSentTimestamp = mailSentTimestamp;
    }

    public String getNick() {
        return nick;
    }

    public void setNick(String nick) {
        this.nick = nick;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }
}

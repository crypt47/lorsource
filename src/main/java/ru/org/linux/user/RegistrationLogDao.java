package ru.org.linux.user;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.BeanPropertyRowMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.ResultSetExtractor;
import org.springframework.stereotype.Repository;

import javax.annotation.Nonnull;
import javax.sql.DataSource;
import java.sql.PreparedStatement;
import java.sql.Types;
import java.time.Duration;
import java.time.temporal.ChronoUnit;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Repository
public class RegistrationLogDao {
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private void setDataSource(DataSource ds) {
        jdbcTemplate = new JdbcTemplate(ds);
    }


    public void recordRegistrationRequest(int userId, String activationCode) {
        jdbcTemplate.update(
                con -> {
                    PreparedStatement st = con.prepareStatement("INSERT INTO registrations_log (user_id, activation_code) VALUES (?,?)");
                    st.setInt(1, userId);
                    st.setString(2, activationCode);
                    return st;
                }
        );
    }

    public void recordMailSent(int userId) {
        jdbcTemplate.update(
                con -> {
                    PreparedStatement st = con.prepareStatement("UPDATE registrations_log SET mail_sent_timestamp=CURRENT_TIMESTAMP WHERE user_id=?");
                    st.setInt(1, userId);
                    return st;
                }
        );
    }

    public List<RegistrationLogItem> getPendingRegistrations() {
        return jdbcTemplate.query("SELECT rl.id, u.id as user_id, u.nick as nick, u.email as email, rl.activation_code, rl.registration_timestamp, rl.mail_sent_timestamp FROM registrations_log rl JOIN  users u ON rl.user_id = u.id WHERE rl.mail_sent_timestamp is null", new BeanPropertyRowMapper<>(RegistrationLogItem.class));
    }

    public int getSentEmailsLastHour() {
        return jdbcTemplate.queryForObject("SELECT COUNT(*) FROM registrations_log rl WHERE rl.mail_sent_timestamp is not null AND rl.mail_sent_timestamp > CURRENT_TIMESTAMP - interval '1 hours'", Integer.class);
    }

    public long getMinutesSinceLastSentEmail() {
        Long duration = jdbcTemplate.queryForObject("select extract( EPOCH from MIN( CURRENT_TIMESTAMP - rl.mail_sent_timestamp)) as duration from registrations_log rl", Long.class);
        return duration != null ? Duration.of(duration, ChronoUnit.SECONDS).toMinutes() : Long.MAX_VALUE;
    }
}

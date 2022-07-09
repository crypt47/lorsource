/*
 * Copyright 1998-2016 Linux.org.ru
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

package ru.org.linux.site;

import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.Date;
import java.util.Locale;

public enum DateFormats {
    ;
    public static final Locale RUSSIAN_LOCALE = new Locale("ru");

    public static java.time.format.DateTimeFormatter getDefaultJavaDateFormat() {
        return java.time.format.DateTimeFormatter.ofPattern("dd.MM.yyyy HH:mm:ss (v)", RUSSIAN_LOCALE);
    }

    public static String format(Date date, String timeZone, java.time.format.DateTimeFormatter dateTimeFormatter) {
        return ZonedDateTime.ofInstant(date.toInstant(), ZoneId.of(timeZone)).format(dateTimeFormatter);
    }

    public static String isoDateTime(Date date, String timeZone) {
        return format(date, timeZone, java.time.format.DateTimeFormatter.ISO_DATE_TIME);
    }

    public static String dateTime(Date date, String timeZone) {
        return format(date, timeZone, getDefaultJavaDateFormat());
    }

    public static String date(Date date, String timeZone) {
        return format(date, timeZone, java.time.format.DateTimeFormatter.ofPattern("dd.MM.yyyy", RUSSIAN_LOCALE));
    }

    public static String time(Date date, String timeZone) {
        return format(date, timeZone, java.time.format.DateTimeFormatter.ofPattern("HH:mm:ss (v)", RUSSIAN_LOCALE));
    }

    public static String rfc(Date date, String timeZone) {
        return format(date, timeZone, java.time.format.DateTimeFormatter.RFC_1123_DATE_TIME);
    }
}

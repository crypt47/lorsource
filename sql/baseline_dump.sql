--
-- PostgreSQL database dump
--

-- Dumped from database version 13.6 (Ubuntu 13.6-0ubuntu0.21.10.1)
-- Dumped by pg_dump version 13.6 (Ubuntu 13.6-0ubuntu0.21.10.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: fuzzystrmatch; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;


--
-- Name: EXTENSION fuzzystrmatch; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION fuzzystrmatch IS 'determine similarities and distance between strings';


--
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;


--
-- Name: EXTENSION hstore; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';


--
-- Name: edit_event_type; Type: TYPE; Schema: public; Owner: linuxtalks
--

CREATE TYPE public.edit_event_type AS ENUM (
    'TOPIC',
    'COMMENT'
);


ALTER TYPE public.edit_event_type OWNER TO linuxtalks;

--
-- Name: event_type; Type: TYPE; Schema: public; Owner: linuxtalks
--

CREATE TYPE public.event_type AS ENUM (
    'WATCH',
    'REPLY',
    'DEL',
    'OTHER',
    'REF',
    'TAG'
);


ALTER TYPE public.event_type OWNER TO linuxtalks;

--
-- Name: markup_type; Type: TYPE; Schema: public; Owner: linuxtalks
--

CREATE TYPE public.markup_type AS ENUM (
    'PLAIN',
    'BBCODE_TEX',
    'BBCODE_ULB',
    'MARKDOWN'
);


ALTER TYPE public.markup_type OWNER TO linuxtalks;

--
-- Name: user_log_action; Type: TYPE; Schema: public; Owner: linuxtalks
--

CREATE TYPE public.user_log_action AS ENUM (
    'reset_userpic',
    'set_userpic',
    'block_user',
    'unblock_user',
    'accept_new_email',
    'reset_info',
    'reset_password',
    'set_password',
    'register',
    'score50',
    'set_corrector',
    'unset_corrector',
    'frozen',
    'defrosted'
);


ALTER TYPE public.user_log_action OWNER TO linuxtalks;

--
-- Name: comins(); Type: FUNCTION; Schema: public; Owner: linuxtalks
--

CREATE FUNCTION public.comins() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
                                  DECLARE
                                          cgroup int;
                                  BEGIN
                                          SELECT groupid INTO cgroup FROM topics WHERE topics.id = NEW.topic;
                                          UPDATE topics SET stat1=stat1+1,stat3=stat3+1,lastmod=CURRENT_TIMESTAMP WHERE topics.id = NEW.topic;
                                          UPDATE groups SET stat3=stat3+1 WHERE id = cgroup;
                                          RETURN NULL;
                                  END;
                                  $$;


ALTER FUNCTION public.comins() OWNER TO linuxtalks;

--
-- Name: create_user_agent(character varying); Type: FUNCTION; Schema: public; Owner: linuxtalks
--

CREATE FUNCTION public.create_user_agent(character varying) RETURNS integer
    LANGUAGE plpgsql STRICT
    AS $_$
DECLARE ua_id INT;
BEGIN
  SELECT count(*) INTO ua_id FROM user_agents WHERE name = $1;
  IF ua_id=0 THEN
    BEGIN
      INSERT INTO user_agents (name) VALUES($1);
    EXCEPTION WHEN unique_violation THEN
      -- do nothing
    END;
  END IF;
  SELECT id INTO ua_id FROM  user_agents WHERE name = $1;
  RETURN ua_id;
END;
$_$;


ALTER FUNCTION public.create_user_agent(character varying) OWNER TO linuxtalks;

--
-- Name: event_delete(); Type: FUNCTION; Schema: public; Owner: linuxtalks
--

CREATE FUNCTION public.event_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
          DECLARE
                  grid int;
                  thetopic topics%ROWTYPE;
                  thecomment comments%ROWTYPE;
          BEGIN
                  SELECT * INTO thetopic FROM topics WHERE id = NEW.msgid;
                  IF FOUND THEN
                          IF thetopic.userid != NEW.delby THEN
                                  INSERT INTO user_events (userid, type, private, message_id, message) VALUES (thetopic.userid, 'DEL', 't', NEW.msgid, NEW.reason);
                          END IF;
                  ELSE
                          SELECT * INTO thecomment FROM comments WHERE id = NEW.msgid;
                          IF thecomment.userid != NEW.delby THEN
                                  INSERT INTO user_events (userid, type, private, message_id, comment_id, message) VALUES (thecomment.userid, 'DEL', 't', thecomment.topic, NEW.msgid, NEW.reason);
                          END IF;
                  END IF;
                  RETURN NULL;
          END;
          $$;


ALTER FUNCTION public.event_delete() OWNER TO linuxtalks;

--
-- Name: get_branch_authors(integer); Type: FUNCTION; Schema: public; Owner: linuxtalks
--

CREATE FUNCTION public.get_branch_authors(comment integer) RETURNS SETOF integer
    LANGUAGE sql
    AS $$
      WITH RECURSIVE r AS
        (SELECT id, replyto, userid FROM comments WHERE id = comment
          UNION
            SELECT comments.id, comments.replyto, comments.userid
            FROM comments JOIN r ON comments.id = r.replyto
        ) SELECT distinct userid from r
      $$;


ALTER FUNCTION public.get_branch_authors(comment integer) OWNER TO linuxtalks;

--
-- Name: get_title(bigint); Type: FUNCTION; Schema: public; Owner: linuxtalks
--

CREATE FUNCTION public.get_title(bigint) RETURNS character varying
    LANGUAGE sql
    AS $_$select title from comments where id=$1 union select title from topics where id=$1$_$;


ALTER FUNCTION public.get_title(bigint) OWNER TO linuxtalks;

--
-- Name: msgdel(); Type: FUNCTION; Schema: public; Owner: linuxtalks
--

CREATE FUNCTION public.msgdel() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
              UPDATE topics SET lastmod=CURRENT_TIMESTAMP WHERE id = NEW.msgid;
              RETURN NULL;
            END;
          $$;


ALTER FUNCTION public.msgdel() OWNER TO linuxtalks;

--
-- Name: msgundel(); Type: FUNCTION; Schema: public; Owner: linuxtalks
--

CREATE FUNCTION public.msgundel() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
                    BEGIN
                      UPDATE topics SET lastmod=CURRENT_TIMESTAMP WHERE id = OLD.msgid;
                      RETURN NULL;
                    END;
                    $$;


ALTER FUNCTION public.msgundel() OWNER TO linuxtalks;

--
-- Name: new_event(); Type: FUNCTION; Schema: public; Owner: linuxtalks
--

CREATE FUNCTION public.new_event() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	UPDATE users SET unread_events=unread_events+1 WHERE users.id = NEW.userid;
	RETURN NULL;
END;
$$;


ALTER FUNCTION public.new_event() OWNER TO linuxtalks;

--
-- Name: normalize_email(text); Type: FUNCTION; Schema: public; Owner: linuxtalks
--

CREATE FUNCTION public.normalize_email(email text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
  DECLARE
    localpart text;
    domainpart text;
  BEGIN
    SELECT regexp_replace(email, '@[^@]*$', '') INTO localpart;
    SELECT regexp_replace(email, '.*@', '') INTO domainpart;

    IF domainpart = 'gmail.com' then
        SELECT regexp_replace(localpart, '[.]', '', 'g') INTO localpart;
    END IF;

    RETURN concat(localpart, '@', domainpart);
  END;
$_$;


ALTER FUNCTION public.normalize_email(email text) OWNER TO linuxtalks;

--
-- Name: stat_update(); Type: FUNCTION; Schema: public; Owner: linuxtalks
--

CREATE FUNCTION public.stat_update() RETURNS timestamp with time zone
    LANGUAGE plpgsql
    AS $$
          DECLARE
                  top record;
                  st record;
                  now timestamp;
          BEGIN
                  now=CURRENT_TIMESTAMP;
                  FOR top IN SELECT id FROM topics WHERE stat3!=0 FOR UPDATE LOOP
                      SELECT count(*) as st1,
                             count(CASE WHEN now-'1 day'::interval<postdate THEN 1 ELSE null END) as st3
                          INTO st
                          FROM comments WHERE topic = top.id AND NOT deleted;

                      UPDATE topics SET stat1=st.st1, stat3=st.st3
                          WHERE id = top.id AND (stat1!=st.st1 OR stat3!=st.st3);
                  END LOOP;
                  RETURN now;
          END;
          $$;


ALTER FUNCTION public.stat_update() OWNER TO linuxtalks;

--
-- Name: stat_update2(); Type: FUNCTION; Schema: public; Owner: linuxtalks
--

CREATE FUNCTION public.stat_update2() RETURNS timestamp with time zone
    LANGUAGE plpgsql
    AS $$
                        DECLARE
                            grp record;
                            s3 int;
                            t3 int;
                            now timestamp;
                        BEGIN
                            now=CURRENT_TIMESTAMP;
                            FOR grp IN SELECT id FROM groups WHERE stat3!=0 FOR UPDATE LOOP
                                SELECT sum(stat3) INTO s3 FROM topics WHERE groupid = grp.id AND NOT deleted AND lastmod>CURRENT_TIMESTAMP-'2 days'::interval;
                                SELECT count(*) INTO t3 FROM topics WHERE groupid = grp.id AND CURRENT_TIMESTAMP-'1 day'::interval<postdate AND NOT deleted;
                                UPDATE groups SET stat3 = s3 + t3 WHERE id = grp.id AND stat3 != s3 + t3;
                            END LOOP;
                            RETURN now;
                        END;
                        $$;


ALTER FUNCTION public.stat_update2() OWNER TO linuxtalks;

--
-- Name: topins(); Type: FUNCTION; Schema: public; Owner: linuxtalks
--

CREATE FUNCTION public.topins() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
                        BEGIN
                            UPDATE groups SET stat3=stat3+1 WHERE groups.id = NEW.groupid;
                            UPDATE topics SET lastmod=CURRENT_TIMESTAMP WHERE id = NEW.id;
                            INSERT INTO memories (userid, topic) VALUES (NEW.userid, NEW.id);
                            RETURN NULL;
                        END;
                        $$;


ALTER FUNCTION public.topins() OWNER TO linuxtalks;

--
-- Name: update_monthly_stats(); Type: FUNCTION; Schema: public; Owner: linuxtalks
--

CREATE FUNCTION public.update_monthly_stats() RETURNS timestamp without time zone
    LANGUAGE plpgsql
    AS $$
begin
delete from monthly_stats;
insert into monthly_stats ( select section, date_part('year', postdate) as year, date_part('month', postdate) as month, count(topics.id) as c from topics, groups, sections where topics.groupid=groups.id and groups.section=sections.id and (topics.moderate or not sections.moderate) and not deleted group by section, year, month);
insert into monthly_stats (section, groupid, year, month, c)  ( select section, groupid, date_part('year', postdate) as year, date_part('month', postdate) as month, count(topics.id) as c from topics, groups, sections where topics.groupid=groups.id and groups.section=sections.id and (topics.moderate or not sections.moderate) and not deleted group by section, groupid, year, month);
return CURRENT_TIMESTAMP;
end;
$$;


ALTER FUNCTION public.update_monthly_stats() OWNER TO linuxtalks;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: b_ips; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.b_ips (
    ip inet NOT NULL,
    mod_id integer NOT NULL,
    date timestamp with time zone NOT NULL,
    reason character varying(255),
    ban_date timestamp with time zone,
    allow_posting boolean DEFAULT false,
    captcha_required boolean DEFAULT true
);


ALTER TABLE public.b_ips OWNER TO linuxtalks;

--
-- Name: TABLE b_ips; Type: COMMENT; Schema: public; Owner: linuxtalks
--

COMMENT ON TABLE public.b_ips IS 'banned ip list table';


--
-- Name: ban_info; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.ban_info (
    userid integer NOT NULL,
    bandate timestamp with time zone DEFAULT now() NOT NULL,
    reason text NOT NULL,
    ban_by integer NOT NULL
);


ALTER TABLE public.ban_info OWNER TO linuxtalks;

--
-- Name: comments; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.comments (
    id integer NOT NULL,
    topic integer NOT NULL,
    userid integer NOT NULL,
    title character varying(255) NOT NULL,
    postdate timestamp with time zone NOT NULL,
    replyto integer,
    deleted boolean DEFAULT false NOT NULL,
    postip inet,
    ua_id integer,
    editor_id integer,
    edit_date timestamp with time zone,
    edit_count integer DEFAULT 0
);


ALTER TABLE public.comments OWNER TO linuxtalks;

--
-- Name: databasechangelog; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.databasechangelog (
    id character varying(255) NOT NULL,
    author character varying(255) NOT NULL,
    filename character varying(255) NOT NULL,
    dateexecuted timestamp with time zone NOT NULL,
    orderexecuted integer NOT NULL,
    exectype character varying(10) NOT NULL,
    md5sum character varying(35),
    description character varying(255),
    comments character varying(255),
    tag character varying(255),
    liquibase character varying(20)
);


ALTER TABLE public.databasechangelog OWNER TO linuxtalks;

--
-- Name: databasechangeloglock; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.databasechangeloglock (
    id integer NOT NULL,
    locked boolean NOT NULL,
    lockgranted timestamp with time zone,
    lockedby character varying(255)
);


ALTER TABLE public.databasechangeloglock OWNER TO linuxtalks;

--
-- Name: del_info; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.del_info (
    msgid integer NOT NULL,
    delby integer NOT NULL,
    reason text,
    deldate timestamp with time zone,
    bonus integer
);


ALTER TABLE public.del_info OWNER TO linuxtalks;

--
-- Name: edit_info; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.edit_info (
    id integer NOT NULL,
    msgid integer NOT NULL,
    editor integer NOT NULL,
    oldmessage text,
    editdate timestamp with time zone DEFAULT now() NOT NULL,
    oldtitle text,
    oldtags text,
    oldlinktext text,
    oldurl text,
    object_type public.edit_event_type DEFAULT 'TOPIC'::public.edit_event_type NOT NULL,
    oldminor boolean,
    oldimage integer,
    oldpoll jsonb
);


ALTER TABLE public.edit_info OWNER TO linuxtalks;

--
-- Name: edit_info_id_seq; Type: SEQUENCE; Schema: public; Owner: linuxtalks
--

CREATE SEQUENCE public.edit_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.edit_info_id_seq OWNER TO linuxtalks;

--
-- Name: edit_info_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: linuxtalks
--

ALTER SEQUENCE public.edit_info_id_seq OWNED BY public.edit_info.id;


--
-- Name: groups; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.groups (
    id integer NOT NULL,
    title character varying(255) NOT NULL,
    image character varying(255),
    section integer NOT NULL,
    stat3 integer DEFAULT 0 NOT NULL,
    restrict_topics integer,
    info text,
    restrict_comments integer DEFAULT '-9999'::integer NOT NULL,
    longinfo text,
    resolvable boolean DEFAULT false NOT NULL,
    urlname text NOT NULL
);


ALTER TABLE public.groups OWNER TO linuxtalks;

--
-- Name: ignore_list; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.ignore_list (
    userid integer NOT NULL,
    ignored integer NOT NULL
);


ALTER TABLE public.ignore_list OWNER TO linuxtalks;

--
-- Name: images; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.images (
    id integer NOT NULL,
    topic integer NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    extension text NOT NULL
);


ALTER TABLE public.images OWNER TO linuxtalks;

--
-- Name: images_id_seq; Type: SEQUENCE; Schema: public; Owner: linuxtalks
--

CREATE SEQUENCE public.images_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.images_id_seq OWNER TO linuxtalks;

--
-- Name: images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: linuxtalks
--

ALTER SEQUENCE public.images_id_seq OWNED BY public.images.id;


--
-- Name: memories; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.memories (
    id integer NOT NULL,
    userid integer NOT NULL,
    topic integer NOT NULL,
    add_date timestamp with time zone DEFAULT now() NOT NULL,
    watch boolean DEFAULT true NOT NULL
);


ALTER TABLE public.memories OWNER TO linuxtalks;

--
-- Name: memories_id_seq; Type: SEQUENCE; Schema: public; Owner: linuxtalks
--

CREATE SEQUENCE public.memories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.memories_id_seq OWNER TO linuxtalks;

--
-- Name: memories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: linuxtalks
--

ALTER SEQUENCE public.memories_id_seq OWNED BY public.memories.id;


--
-- Name: monthly_stats; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.monthly_stats (
    section integer,
    year integer NOT NULL,
    month integer NOT NULL,
    c integer NOT NULL,
    groupid integer
);


ALTER TABLE public.monthly_stats OWNER TO linuxtalks;

--
-- Name: msgbase; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.msgbase (
    id bigint NOT NULL,
    message text NOT NULL,
    markup public.markup_type DEFAULT 'BBCODE_TEX'::public.markup_type NOT NULL
);


ALTER TABLE public.msgbase OWNER TO linuxtalks;

--
-- Name: polls; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.polls (
    id integer NOT NULL,
    topic integer DEFAULT 0 NOT NULL,
    multiselect boolean DEFAULT false NOT NULL
);


ALTER TABLE public.polls OWNER TO linuxtalks;

--
-- Name: polls_variants; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.polls_variants (
    id integer NOT NULL,
    vote integer NOT NULL,
    label text NOT NULL,
    votes integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.polls_variants OWNER TO linuxtalks;

--
-- Name: s_guid; Type: SEQUENCE; Schema: public; Owner: linuxtalks
--

CREATE SEQUENCE public.s_guid
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


ALTER TABLE public.s_guid OWNER TO linuxtalks;

--
-- Name: s_msg; Type: SEQUENCE; Schema: public; Owner: linuxtalks
--

CREATE SEQUENCE public.s_msg
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


ALTER TABLE public.s_msg OWNER TO linuxtalks;

--
-- Name: s_msgid; Type: SEQUENCE; Schema: public; Owner: linuxtalks
--

CREATE SEQUENCE public.s_msgid
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


ALTER TABLE public.s_msgid OWNER TO linuxtalks;

--
-- Name: s_uid; Type: SEQUENCE; Schema: public; Owner: linuxtalks
--

CREATE SEQUENCE public.s_uid
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


ALTER TABLE public.s_uid OWNER TO linuxtalks;

--
-- Name: sections; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.sections (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    moderate boolean NOT NULL,
    imagepost boolean NOT NULL,
    linktext character varying(255),
    havelink boolean NOT NULL,
    expire interval NOT NULL,
    vote boolean DEFAULT false,
    add_info text,
    scroll_mode character varying(10) DEFAULT 'NO_SCROLL'::character varying NOT NULL,
    restrict_topics integer DEFAULT '-50'::integer,
    imageallowed boolean DEFAULT false NOT NULL
);


ALTER TABLE public.sections OWNER TO linuxtalks;

--
-- Name: tags; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.tags (
    msgid integer,
    tagid integer
);


ALTER TABLE public.tags OWNER TO linuxtalks;

--
-- Name: tags_values; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.tags_values (
    id integer NOT NULL,
    counter integer DEFAULT 0,
    value character varying(255) NOT NULL
);


ALTER TABLE public.tags_values OWNER TO linuxtalks;

--
-- Name: tags_values_id_seq; Type: SEQUENCE; Schema: public; Owner: linuxtalks
--

CREATE SEQUENCE public.tags_values_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tags_values_id_seq OWNER TO linuxtalks;

--
-- Name: tags_values_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: linuxtalks
--

ALTER SEQUENCE public.tags_values_id_seq OWNED BY public.tags_values.id;


--
-- Name: telegram_posts; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.telegram_posts (
    topic_id integer NOT NULL,
    telegram_id integer NOT NULL,
    postdate timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.telegram_posts OWNER TO linuxtalks;

--
-- Name: topic_users_notified; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.topic_users_notified (
    topic integer NOT NULL,
    userid integer NOT NULL
);


ALTER TABLE public.topic_users_notified OWNER TO linuxtalks;

--
-- Name: topics; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.topics (
    id integer NOT NULL,
    groupid integer NOT NULL,
    userid integer NOT NULL,
    title character varying(255) NOT NULL,
    url character varying(255),
    moderate boolean DEFAULT false NOT NULL,
    postdate timestamp with time zone NOT NULL,
    linktext character varying(255),
    deleted boolean DEFAULT false NOT NULL,
    stat1 integer DEFAULT 0 NOT NULL,
    stat3 integer DEFAULT 0 NOT NULL,
    lastmod timestamp with time zone NOT NULL,
    commitby integer,
    notop boolean DEFAULT false NOT NULL,
    commitdate timestamp with time zone,
    postscore integer,
    postip inet,
    sticky boolean DEFAULT false NOT NULL,
    ua_id integer,
    resolved boolean,
    minor boolean DEFAULT false NOT NULL,
    draft boolean DEFAULT false NOT NULL,
    allow_anonymous boolean DEFAULT true NOT NULL
);


ALTER TABLE public.topics OWNER TO linuxtalks;

--
-- Name: user_agents; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.user_agents (
    id integer NOT NULL,
    name character varying(512) DEFAULT ''::character varying
);


ALTER TABLE public.user_agents OWNER TO linuxtalks;

--
-- Name: user_agents_id_seq; Type: SEQUENCE; Schema: public; Owner: linuxtalks
--

CREATE SEQUENCE public.user_agents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_agents_id_seq OWNER TO linuxtalks;

--
-- Name: user_agents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: linuxtalks
--

ALTER SEQUENCE public.user_agents_id_seq OWNED BY public.user_agents.id;


--
-- Name: user_events; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.user_events (
    userid integer NOT NULL,
    type public.event_type NOT NULL,
    private boolean NOT NULL,
    event_date timestamp with time zone DEFAULT now() NOT NULL,
    message_id integer,
    comment_id integer,
    message text,
    unread boolean DEFAULT true NOT NULL,
    id integer NOT NULL
);


ALTER TABLE public.user_events OWNER TO linuxtalks;

--
-- Name: user_events_id_seq; Type: SEQUENCE; Schema: public; Owner: linuxtalks
--

CREATE SEQUENCE public.user_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_events_id_seq OWNER TO linuxtalks;

--
-- Name: user_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: linuxtalks
--

ALTER SEQUENCE public.user_events_id_seq OWNED BY public.user_events.id;


--
-- Name: user_invites; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.user_invites (
    invite_code text NOT NULL,
    owner integer NOT NULL,
    issue_date timestamp with time zone DEFAULT now() NOT NULL,
    invited_user integer,
    email text NOT NULL,
    valid_until timestamp with time zone NOT NULL
);


ALTER TABLE public.user_invites OWNER TO linuxtalks;

--
-- Name: user_log; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.user_log (
    id integer NOT NULL,
    userid integer NOT NULL,
    action_userid integer NOT NULL,
    action_date timestamp with time zone NOT NULL,
    action public.user_log_action NOT NULL,
    info public.hstore NOT NULL
);


ALTER TABLE public.user_log OWNER TO linuxtalks;

--
-- Name: user_log_id_seq; Type: SEQUENCE; Schema: public; Owner: linuxtalks
--

CREATE SEQUENCE public.user_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_log_id_seq OWNER TO linuxtalks;

--
-- Name: user_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: linuxtalks
--

ALTER SEQUENCE public.user_log_id_seq OWNED BY public.user_log.id;


--
-- Name: user_remarks; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.user_remarks (
    id integer NOT NULL,
    user_id integer NOT NULL,
    ref_user_id integer NOT NULL,
    remark_text character varying(255) NOT NULL
);


ALTER TABLE public.user_remarks OWNER TO linuxtalks;

--
-- Name: user_remarks_id_seq; Type: SEQUENCE; Schema: public; Owner: linuxtalks
--

CREATE SEQUENCE public.user_remarks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_remarks_id_seq OWNER TO linuxtalks;

--
-- Name: user_remarks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: linuxtalks
--

ALTER SEQUENCE public.user_remarks_id_seq OWNED BY public.user_remarks.id;


--
-- Name: user_settings; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.user_settings (
    id integer NOT NULL,
    settings public.hstore NOT NULL,
    main text[]
);


ALTER TABLE public.user_settings OWNER TO linuxtalks;

--
-- Name: user_tags; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.user_tags (
    user_id integer,
    tag_id integer,
    is_favorite boolean DEFAULT false
);


ALTER TABLE public.user_tags OWNER TO linuxtalks;

--
-- Name: users; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.users (
    id integer NOT NULL,
    name character varying(255),
    nick character varying(80) NOT NULL,
    passwd character varying(40),
    url character varying(255),
    email character varying(255),
    canmod boolean DEFAULT false NOT NULL,
    photo character varying(100),
    town character varying(100),
    candel boolean DEFAULT false NOT NULL,
    lostpwd timestamp with time zone DEFAULT '1970-01-01 01:00:00+01'::timestamp with time zone NOT NULL,
    blocked boolean,
    score integer,
    max_score integer,
    lastlogin timestamp with time zone,
    regdate timestamp with time zone,
    activated boolean DEFAULT false NOT NULL,
    corrector boolean DEFAULT false NOT NULL,
    userinfo text,
    unread_events integer DEFAULT 0 NOT NULL,
    new_email character varying(255),
    style character varying(15) DEFAULT 'tango'::character varying NOT NULL,
    token_generation integer DEFAULT 0,
    frozen_until timestamp with time zone,
    frozen_by integer,
    freezing_reason character varying(255)
);


ALTER TABLE public.users OWNER TO linuxtalks;

--
-- Name: vote_id; Type: SEQUENCE; Schema: public; Owner: linuxtalks
--

CREATE SEQUENCE public.vote_id
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


ALTER TABLE public.vote_id OWNER TO linuxtalks;

--
-- Name: vote_users; Type: TABLE; Schema: public; Owner: linuxtalks
--

CREATE TABLE public.vote_users (
    vote integer NOT NULL,
    userid integer NOT NULL,
    variant_id integer
);


ALTER TABLE public.vote_users OWNER TO linuxtalks;

--
-- Name: votes_id; Type: SEQUENCE; Schema: public; Owner: linuxtalks
--

CREATE SEQUENCE public.votes_id
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


ALTER TABLE public.votes_id OWNER TO linuxtalks;

--
-- Name: edit_info id; Type: DEFAULT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.edit_info ALTER COLUMN id SET DEFAULT nextval('public.edit_info_id_seq'::regclass);


--
-- Name: images id; Type: DEFAULT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.images ALTER COLUMN id SET DEFAULT nextval('public.images_id_seq'::regclass);


--
-- Name: memories id; Type: DEFAULT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.memories ALTER COLUMN id SET DEFAULT nextval('public.memories_id_seq'::regclass);


--
-- Name: tags_values id; Type: DEFAULT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.tags_values ALTER COLUMN id SET DEFAULT nextval('public.tags_values_id_seq'::regclass);


--
-- Name: user_agents id; Type: DEFAULT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_agents ALTER COLUMN id SET DEFAULT nextval('public.user_agents_id_seq'::regclass);


--
-- Name: user_events id; Type: DEFAULT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_events ALTER COLUMN id SET DEFAULT nextval('public.user_events_id_seq'::regclass);


--
-- Name: user_log id; Type: DEFAULT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_log ALTER COLUMN id SET DEFAULT nextval('public.user_log_id_seq'::regclass);


--
-- Name: user_remarks id; Type: DEFAULT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_remarks ALTER COLUMN id SET DEFAULT nextval('public.user_remarks_id_seq'::regclass);


--
-- Data for Name: b_ips; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.b_ips (ip, mod_id, date, reason, ban_date, allow_posting, captcha_required) FROM stdin;
\.


--
-- Data for Name: ban_info; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.ban_info (userid, bandate, reason, ban_by) FROM stdin;
\.


--
-- Data for Name: comments; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.comments (id, topic, userid, title, postdate, replyto, deleted, postip, ua_id, editor_id, edit_date, edit_count) FROM stdin;
\.


--
-- Data for Name: databasechangelog; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.databasechangelog (id, author, filename, dateexecuted, orderexecuted, exectype, md5sum, description, comments, tag, liquibase) FROM stdin;
2011122301	hizel	sql/updates/2011-12-23-poll.xml	2022-05-21 15:09:17.632668+02	1	EXECUTED	7:ba7047da8ed0c33d4042423f7cb7c425	renameTable (x2), addColumn, dropIndex, createIndex		\N	3.1.1
2011122302	hizel	sql/updates/2011-12-23-themed-wiki.xml	2022-05-21 15:09:17.659382+02	2	EXECUTED	7:6c4afc6acbba6c00c140414bd173211f	createView		\N	3.1.1
2011122501	Slava Zanko	sql/updates/2011-12-25-ban.xml	2022-05-21 15:09:17.679989+02	3	EXECUTED	7:2e2aae8729b0e1b977d7107072149d1f	addColumn		\N	3.1.1
2011122901	Slava Zanko	sql/updates/2011-12-29-section-scrollMode.xml	2022-05-21 15:09:17.700826+02	4	EXECUTED	7:f7262227602f80245447e570aa143eab	addColumn, update (x3)		\N	3.1.1
2011122902	Slava Zanko	sql/updates/2011-12-29-section-scrollMode.xml	2022-05-21 15:09:17.719405+02	5	EXECUTED	7:3caf3ef12f18466b4869ef065b55d268	addNotNullConstraint		\N	3.1.1
2012012401	Maxim Valyanskiy	sql/updates/2012-01-24-delscore.xml	2022-05-21 15:09:17.738283+02	6	EXECUTED	7:9d10979591324ab37b324a664287ef2e	addColumn		\N	3.1.1
2012020201	hizel	sql/updates/2012-02-02-grant-wiki.xml	2022-05-21 15:09:17.758223+02	7	EXECUTED	7:5746794d9a1891dd8371d75f90feb4eb	sql		\N	3.1.1
2012021601	linuxtalks	sql/updates/2012-02-16-topic-perm-fix.xml	2022-05-21 15:09:17.775519+02	8	EXECUTED	7:54bb1052bf1530b7801f843800b95091	update		\N	3.1.1
2012021701	Maxim Valyanskiy	sql/updates/2012-02-17-section-score.xml	2022-05-21 15:09:17.794836+02	9	EXECUTED	7:06967ea819930347e7bd74cf947f9e79	addColumn		\N	3.1.1
2012022801	Slava Zanko	sql/updates/2012-02-28-tags-first-letter-index.xml	2022-05-21 15:09:17.815655+02	10	EXECUTED	7:b1e7876f82944d50e7a47cec6b487618	sql		\N	3.1.1
2012031901	Slava Zanko	sql/updates/2012-03-19-tags_values-grant-delete.xml	2022-05-21 15:09:17.831742+02	11	EXECUTED	7:278a879628587d303c5dc34c280be543	sql		\N	3.1.1
2012032001	hizel	sql/updates/2012-03-20-grant-move-wiki-moder.xml	2022-05-21 15:09:17.850775+02	12	EXECUTED	7:f78f2a994db48f2d86b1da8405113e93	sql		\N	3.1.1
2012032301	Slava Zanko	sql/updates/2012-03-23-user-tags-table.xml	2022-05-21 15:09:17.872571+02	13	EXECUTED	7:29fe518bbfbc49323e129635ae082780	createTable		\N	3.1.1
2012032302	Slava Zanko	sql/updates/2012-03-23-user-tags-table.xml	2022-05-21 15:09:17.903382+02	14	EXECUTED	7:d3d3e319304fd1bec540a2ce5ef809b7	createIndex (x3)		\N	3.1.1
2012032303	Slava Zanko	sql/updates/2012-03-23-user-tags-table.xml	2022-05-21 15:09:17.920341+02	15	EXECUTED	7:6edf9196d4634956d1520748b2bc8bea	sql		\N	3.1.1
2012032601	Maxim Valyanskiy	sql/updates/2012-03-26-drop-sections-preformat.xml	2022-05-21 15:09:17.936204+02	16	EXECUTED	7:753bb64ed62f69a4bac70696d067f039	dropColumn		\N	3.1.1
2012032701	Slava Zanko	sql/updates/2012-03-27-add-value-to-event_type.xml	2022-05-21 15:09:17.948767+02	17	MARK_RAN	7:7569e28704b1040d352cf488ac6b5f8e	sql		\N	3.1.1
2012033001	Slava Zanko	sql/updates/2012-03-30-add-value-to-event_type-9.1.xml	2022-05-21 15:09:17.964451+02	18	EXECUTED	7:612ea12e31cf8f40cdedf2ff3484a883	sql		\N	3.1.1
2012042501	Maxim Valyanskiy	sql/updates/2012-04-25-sticky-index.xml	2022-05-21 15:09:17.985887+02	19	EXECUTED	7:e962014fcfb87a5291dce1f33e4b4f81	sql		\N	3.1.1
2012050401	Maxim Valyanskiy	sql/updates/2012-05-04-comdel-to-java.xml	2022-05-21 15:09:18.003336+02	20	EXECUTED	7:0a764f4458d4c45de03e0e4235842f9e	sql		\N	3.1.1
2012050606	Maxim Valyanskiy	sql/updates/2012-05-06-optimize-statupdate2.xml	2022-05-21 15:09:18.018951+02	21	EXECUTED	7:7f0a4e7e5fbf1a72b532f37fcfd5b61a	sql		\N	3.1.1
2012050601	Maxim Valyanskiy	sql/updates/2012-05-06-remove-groups-stat4.xml	2022-05-21 15:09:18.03609+02	22	EXECUTED	7:7f6ce812bc25210771a82d880f894af2	sql, dropColumn		\N	3.1.1
2012050602	Maxim Valyanskiy	sql/updates/2012-05-06-remove-groups-stat4.xml	2022-05-21 15:09:18.051521+02	23	EXECUTED	7:6d43c42c7e5efb02b1d8feb20499e1ec	sql		\N	3.1.1
2012050603	Maxim Valyanskiy	sql/updates/2012-05-06-remove-groups-stat4.xml	2022-05-21 15:09:18.06751+02	24	EXECUTED	7:befaf8f64c8fb49bc3c614eefbced892	sql		\N	3.1.1
2012050703	Slava Zanko	sql/updates/2012-05-07-add-comment-edit-info.xml	2022-05-21 15:09:18.085781+02	25	EXECUTED	7:45967bfa038987c1c6575ee3c1b3ad45	addColumn (x3)		\N	3.1.1
2012050701	Slava Zanko	sql/updates/2012-05-07-add-edithistory-type.xml	2022-05-21 15:09:18.102485+02	26	EXECUTED	7:f550db97a0fd7ba3484e9e17958343dc	sql		\N	3.1.1
2012050702	Slava Zanko	sql/updates/2012-05-07-add-edithistory-type.xml	2022-05-21 15:09:18.116575+02	27	EXECUTED	7:94de442529826e48d9b0d1608f3f6903	sql		\N	3.1.1
2012051101	Maxim Valyanskiy	sql/updates/2012-05-11-memories-type.xml	2022-05-21 15:09:18.136863+02	28	EXECUTED	7:311266eb03f6b72f3600cefed66034f6	addColumn, sql		\N	3.1.1
2012051102	Maxim Valyanskiy	sql/updates/2012-05-11-memories-type.xml	2022-05-21 15:09:18.151776+02	29	EXECUTED	7:537fd36694452a6bc88acd30f39fcfa1	sql		\N	3.1.1
2012051201	Maxim Valyanskiy	sql/updates/2012-05-12-memories-topic-index.xml	2022-05-21 15:09:18.171844+02	30	EXECUTED	7:88148db59220bd4246b60939e4134faf	sql		\N	3.1.1
2012060501	Maxim Valyanskiy	sql/updates/2012-06-05-remove-groups-stat2.xml	2022-05-21 15:09:18.187316+02	31	EXECUTED	7:d000dd1669f135cecbdfb5bd4bf2ddcb	sql, dropColumn		\N	3.1.1
2012060502	Maxim Valyanskiy	sql/updates/2012-06-05-remove-groups-stat2.xml	2022-05-21 15:09:18.203378+02	32	EXECUTED	7:c527baa5545d4fe25587c21760e896b3	sql		\N	3.1.1
2012060503	Maxim Valyanskiy	sql/updates/2012-06-05-remove-groups-stat2.xml	2022-05-21 15:09:18.217764+02	33	EXECUTED	7:8c663b6567df268a5434afffa974063e	sql		\N	3.1.1
2012072001	Maxim Valyanskiy	sql/updates/2012-07-20-images-table.xml	2022-05-21 15:09:18.248696+02	34	EXECUTED	7:5aa0747f15eef2d3bcd2a23b1446b2b6	createTable, sql		\N	3.1.1
2012072002	Maxim Valynskiy	sql/updates/2012-07-20-images-table.xml	2022-05-21 15:09:18.261085+02	35	EXECUTED	7:dc69f2158dfb5f45023e502596ceffcb	sql		\N	3.1.1
2012072003	Maxim Valynskiy	sql/updates/2012-07-20-images-table.xml	2022-05-21 15:09:18.273803+02	36	EXECUTED	7:30d8b3f529b45a5888c813cd37e89aeb	sql		\N	3.1.1
2012072701	Maxim Valyanskiy	sql/updates/2012-07-27-drop-check-replyto.xml	2022-05-21 15:09:18.285818+02	37	EXECUTED	7:d4e83c4cf82b2fdb3797ccada37d9810	sql		\N	3.1.1
2012082801	Maxim Valyanskiy	sql/updates/2012-08-28-add-imageallowed.xml	2022-05-21 15:09:18.299187+02	38	EXECUTED	7:5bb9eb8b90d0d696f087a0ac7e1dc1e6	addColumn, update		\N	3.1.1
2012083001	Maxim Valyanskiy	sql/updates/2012-08-30-add-editminor.xml	2022-05-21 15:09:18.313254+02	39	EXECUTED	7:bee741bba204208fbad38f3dd48ecd44	addColumn		\N	3.1.1
2012091310	Maxim Valyanskiy	sql/updates/2012-09-13-add-editimage.xml	2022-05-21 15:09:18.329512+02	40	EXECUTED	7:38eb2157972921c112331bdfc34285a6	addColumn		\N	3.1.1
2012091301	Maxim Valyanskiy	sql/updates/2012-09-13-add-image-delete.xml	2022-05-21 15:09:18.344471+02	41	EXECUTED	7:0a5b3f1c76fef54da55cd15c0114481b	addColumn		\N	3.1.1
2012091302	Maxim Valyanskiy	sql/updates/2012-09-13-add-image-delete.xml	2022-05-21 15:09:18.357918+02	42	EXECUTED	7:42f32ed65717173bdfda5b3e99983a77	sql		\N	3.1.1
2012091331	Maxim Valyanskiy	sql/updates/2012-09-13-editinfo-type-notnull.xml	2022-05-21 15:09:18.370506+02	43	EXECUTED	7:244d08e66d5c1f98b69d0116a8dc766e	addNotNullConstraint		\N	3.1.1
2012091801	Yury Fedorchenko	sql/updates/2012-09-18-user-of-usercomments-table.xml	2022-05-21 15:09:18.389624+02	44	EXECUTED	7:84ddcdf8440c6ea5779126904953f878	createTable		\N	3.1.1
2012091802	Yury Fedorchenko	sql/updates/2012-09-18-user-of-usercomments-table.xml	2022-05-21 15:09:18.413281+02	45	EXECUTED	7:cdbc43fe42dfeec3b171e0b06dd7f67b	createIndex (x2)		\N	3.1.1
2012091803	Yury Fedorchenko	sql/updates/2012-09-18-user-of-usercomments-table.xml	2022-05-21 15:09:18.427972+02	46	EXECUTED	7:dfa3edbe6d8d41be37cb5cb4f705bc32	sql		\N	3.1.1
2012091804	Yury Fedorchenko	sql/updates/2012-09-18-user-of-usercomments-table.xml	2022-05-21 15:09:18.442143+02	47	EXECUTED	7:2f06d9bd5ae96e7978ebe1825bcf8e77	sql		\N	3.1.1
2012100201	hizel	sql/updates/2012-10-02-security-remember-logins.xml	2022-05-21 15:09:18.461273+02	48	EXECUTED	7:bf94ff54cd054a786e53b024acede1cd	createTable		\N	3.1.1
2012100202	hizel	sql/updates/2012-10-02-security-remember-logins.xml	2022-05-21 15:09:18.476069+02	49	EXECUTED	7:f16aeb890add770eb5313d284a3d4288	sql		\N	3.1.1
2012103101	hizel	sql/updates/2012-10-31-remove-remember-repo.xml	2022-05-21 15:09:18.490099+02	50	EXECUTED	7:d3c1f80bf01c852c2ee0f596d4d4c857	dropTable		\N	3.1.1
2012111401	Maxim Valyanskiy	sql/updates/2012-11-14-unactivated-index.xml	2022-05-21 15:09:18.507997+02	51	EXECUTED	7:147a81d240414b4f20136819516be0c2	sql		\N	3.1.1
2013011801	Maxim Valyanskiy	sql/updates/2013-01-18-tagcloud-idx.xml	2022-05-21 15:09:18.525401+02	52	EXECUTED	7:c449ab3699aa1d6bb6c4b0feea50966a	sql		\N	3.1.1
2013011901	Maxim Valyanskiy	sql/updates/2013-01-19-vote_idx.xml	2022-05-21 15:09:18.607975+02	53	EXECUTED	7:30fcc9b7a63fce21d8cee4fee8845dc4	sql		\N	3.1.1
2013012102	Maxim Valyanskiy	sql/updates/2013-01-21-optimize_stat_update.xml	2022-05-21 15:09:18.6226+02	54	EXECUTED	7:90b1b2248d77e26a86110f7aa8dfc113	sql		\N	3.1.1
2013030101	Maxim Valyanskiy	sql/updates/2013-03-11-user_comments_count.xml	2022-05-21 15:09:18.644845+02	55	EXECUTED	7:c84bef0464a8f619b3616435a694f938	sql		\N	3.1.1
2013030102	Maxim Valyanskiy	sql/updates/2013-03-11-user_comments_count.xml	2022-05-21 15:09:18.66124+02	56	EXECUTED	7:ab125e24dc2e1ebfc8d7d99b1fcb60f3	sql		\N	3.1.1
2013032601	Maxim Valyanskiy	sql/updates/2013-03-26-hstore.xml	2022-05-21 15:09:18.689489+02	57	EXECUTED	7:306b10187b2fb586f69c6917fb61ba38	sql		\N	3.1.1
2013032602	Maxim Valyanskiy	sql/updates/2013-03-26-hstore.xml	2022-05-21 15:09:18.710964+02	58	EXECUTED	7:1aac2a7e421a84df3aa51023797e9708	sql		\N	3.1.1
2013032603	Maxim Valyanskiy	sql/updates/2013-03-26-hstore.xml	2022-05-21 15:09:18.724481+02	59	EXECUTED	7:b1fa6ea11a6c5eb7bd3c932185c0f5bf	sql		\N	3.1.1
2013040105	Maxim Valyanskiy	sql/updates/2013-04-01-userlog.xml	2022-05-21 15:09:18.751205+02	60	EXECUTED	7:f9dee57c4223f0769cb8f95bcfaadb50	sql		\N	3.1.1
2013040106	Maxim Valyanskiy	sql/updates/2013-04-01-userlog.xml	2022-05-21 15:09:18.766673+02	61	EXECUTED	7:b6e7e06dfd2d36060fbd32a415df2b8e	sql		\N	3.1.1
2013040107	Maxim Valyanskiy	sql/updates/2013-04-01-userlog.xml	2022-05-21 15:09:18.780571+02	62	EXECUTED	7:5ac6a17df1da1368fb27c423a87de49d	sql		\N	3.1.1
2013050701	Maxim Valyanskiy	sql/updates/2013-05-07-topic_users_notified.xml	2022-05-21 15:09:18.796291+02	63	EXECUTED	7:9edaf1bd6cd72a43d33f6d41df701720	createTable		\N	3.1.1
2013050702	Maxim Valynskiy	sql/updates/2013-05-07-topic_users_notified.xml	2022-05-21 15:09:18.814813+02	64	EXECUTED	7:8c93eb2611a69d7bcf8302c710864c65	sql		\N	3.1.1
2013050703	Maxim Valynskiy	sql/updates/2013-05-07-topic_users_notified.xml	2022-05-21 15:09:18.828709+02	65	EXECUTED	7:f179b025c83b316a13debae984dafc14	sql		\N	3.1.1
2013052803	Slava Zanko	sql/updates/2013-05-28-ignored-index.xml	2022-05-21 15:09:18.847099+02	66	EXECUTED	7:e6245e21abaefc645dd1a6c8c05877ac	createIndex		\N	3.1.1
2013061901	hizel	sql/updates/2013-06-19-msg-type-field.xml	2022-05-21 15:09:18.860977+02	67	EXECUTED	7:8debc12a4a74e3f80e4c2d56f171b23d	sql		\N	3.1.1
2013061902	hizel	sql/updates/2013-06-19-msg-type-field.xml	2022-05-21 15:09:18.875628+02	68	EXECUTED	7:07182773a93e8a83eec567edb9c3b421	addColumn		\N	3.1.1
2013061903	hizel	sql/updates/2013-06-19-msg-type-field.xml	2022-05-21 15:09:18.890079+02	69	EXECUTED	7:bb3cda3714fad779012f36da5b4213cb	sql		\N	3.1.1
2013061904	hizel	sql/updates/2013-06-19-msg-type-field.xml	2022-05-21 15:09:18.90441+02	70	EXECUTED	7:3d6851332fb5f856a352fce2df30d483	dropColumn		\N	3.1.1
2013062401	Maxim Valyanskiy	sql/updates/2013-06-24-draft-field.xml	2022-05-21 15:09:18.919315+02	71	EXECUTED	7:fc852f24be7fadd11bf1752822947404	addColumn		\N	3.1.1
2013082702	Maxim Valyanskiy	sql/updates/2013-08-27-editinfo_register.xml	2022-05-21 15:09:18.933318+02	72	EXECUTED	7:d16ca743965d4c4638ba4cdf8618beb2	sql		\N	3.1.1
2013091001	Maxim Valyanskiy	sql/updates/2013-09-10-tags-prefix-index.xml	2022-05-21 15:09:18.951374+02	73	EXECUTED	7:c93d755ee168b96366e509a54ae64426	sql		\N	3.1.1
2013091104	Maxim Valyanskiy	sql/updates/2013-09-11-userlog-cascade.xml	2022-05-21 15:09:18.979949+02	74	EXECUTED	7:c3b3fe2943acd1069e10628b6737eaed	sql		\N	3.1.1
2013091103	Maxim Valyanskiy	sql/updates/2013-09-11-userlog-cascade.xml	2022-05-21 15:09:18.996236+02	75	EXECUTED	7:f629781ab970406ed0676d0a865585c7	sql		\N	3.1.1
2013092303	Maxim Valyanskiy	sql/updates/2013-09-23-drop-unused-idx.xml	2022-05-21 15:09:19.010124+02	76	EXECUTED	7:e419fc1341f46608e72ee2e781a23e91	dropIndex		\N	3.1.1
2013092301	Maxim Valyanskiy	sql/updates/2013-09-23-event_delete_simplify.xml	2022-05-21 15:09:19.023973+02	77	EXECUTED	7:62873a4444d5badf18443faf39d27925	sql		\N	3.1.1
2013092302	Maxim Valyanskiy	sql/updates/2013-09-23-userevents-indexes.xml	2022-05-21 15:09:19.047053+02	78	EXECUTED	7:431f81ff5301b19943c7bd9a3754da67	createIndex (x2)		\N	3.1.1
2013102701	Maxim Valyanskiy	sql/updates/2013-10-27-remove-edit-trigger.xml	2022-05-21 15:09:19.060998+02	79	EXECUTED	7:45fb387c10e4daed99973684e72c5976	sql		\N	3.1.1
2014010701	Maxim Valyanskiy	sql/updates/2014-01-07-notop-fix.xml	2022-05-21 15:09:19.074508+02	80	EXECUTED	7:ce4c932fc74abb256b94b3670ff54e0c	sql		\N	3.1.1
2014030601	Maxim Valyanskiy	sql/updates/2014-03-06-userlog_score50.xml	2022-05-21 15:09:19.08763+02	81	EXECUTED	7:15083d88c075fdb77d810496e92af3c7	sql		\N	3.1.1
2014032801	Maxim Valyanskiy	sql/updates/2014-03-28-userlog_corrector.xml	2022-05-21 15:09:19.104663+02	82	EXECUTED	7:6730cd792ac38f50d23a9ddb8eea6cf8	sql		\N	3.1.1
2014051301	Maxim Valyanskiy	sql/updates/2014-05-13-drop-user_comments_count.xml	2022-05-21 15:09:19.11979+02	83	EXECUTED	7:a6272ed8b24978511a07ea4157d1fc3c	dropTable		\N	3.1.1
2014072401	Maxim Valyanskiy	sql/updates/2014-07-24-drop-group-stat1.xml	2022-05-21 15:09:19.134681+02	84	EXECUTED	7:f08f5d7ef772f407e7f23505f8e2442d	sql		\N	3.1.1
2014072402	Maxim Valyanskiy	sql/updates/2014-07-24-drop-group-stat1.xml	2022-05-21 15:09:19.149097+02	85	EXECUTED	7:12862a279d4f93f532e425acba5b1911	dropColumn		\N	3.1.1
2014072403	Maxim Valyanskiy	sql/updates/2014-07-24-drop-group-stat1.xml	2022-05-21 15:09:19.162629+02	86	EXECUTED	7:8b885bf58933930cfbf6d88564661d45	sql		\N	3.1.1
2014072404	Maxim Valyanskiy	sql/updates/2014-07-24-drop-group-stat1.xml	2022-05-21 15:09:19.175812+02	87	EXECUTED	7:095a25b4c4daf48693d3aa40f71df3f4	sql		\N	3.1.1
2014072405	Maxim Valyanskiy	sql/updates/2014-07-24-drop-group-stat1.xml	2022-05-21 15:09:19.189264+02	88	EXECUTED	7:a58b64964b1f2020fae143db33ba0dc5	sql		\N	3.1.1
2014072406	Maxim Valyanskiy	sql/updates/2014-07-24-drop-group-stat1.xml	2022-05-21 15:09:19.202585+02	89	EXECUTED	7:de6cec37b10bc2f3e24bd6f49488017f	sql		\N	3.1.1
2014081201	Maxim Valyanskiy	sql/updates/2014-08-12-optimize-statupdate2.xml	2022-05-21 15:09:19.215863+02	90	EXECUTED	7:2aa31bd56f5626565b1e75b66371460a	sql		\N	3.1.1
2014101601	Maxim Valyanskiy	sql/updates/2014-10-16-drop-unused-idx.xml	2022-05-21 15:09:19.228798+02	91	EXECUTED	7:f3f9034415e1921bf46f2cdc3806c966	dropIndex		\N	3.1.1
2014102701	Maxim Valyanskiy	sql/updates/2014-10-27-timestamp-timezone.xml	2022-05-21 15:09:19.264843+02	92	EXECUTED	7:fccb3ae291ecba043d0ddb7d96988041	sql		\N	3.1.1
2014102702	Maxim Valyanskiy	sql/updates/2014-10-27-timestamp-timezone.xml	2022-05-21 15:09:19.404518+02	93	EXECUTED	7:fedf661f73af0391c28072dbcb64d025	sql		\N	3.1.1
2014102703	Maxim Valyanskiy	sql/updates/2014-10-27-timestamp-timezone.xml	2022-05-21 15:09:19.451365+02	94	EXECUTED	7:a8950516a9cd6a877f9b1bea91e6013d	sql		\N	3.1.1
2014102901	Maxim Valyanskiy	sql/updates/2014-10-27-timestamp-timezone.xml	2022-05-21 15:09:19.463159+02	95	EXECUTED	7:f3a065ac84b719d6ef5e7df825dce253	sql		\N	3.1.1
2014111501	Maxim Valyanskiy	sql/updates/2014-11-15-remove-topic-deleted-column.xml	2022-05-21 15:09:19.474973+02	96	EXECUTED	7:97852301dd08075272dab31e8f782f7d	sql		\N	3.1.1
2014111502	Maxim Valyanskiy	sql/updates/2014-11-15-remove-topic-deleted-column.xml	2022-05-21 15:09:19.486422+02	97	EXECUTED	7:27f81dbef23dc500f4e96e614849ae00	sql		\N	3.1.1
2014111503	Maxim Valyanskiy	sql/updates/2014-11-15-remove-topic-deleted-column.xml	2022-05-21 15:09:19.498121+02	98	EXECUTED	7:128832a2c25211c38674e3a86c7c2d2f	dropColumn		\N	3.1.1
2015022801	Maxim Valyanskiy	sql/updates/2015-02-28-remove-topics-stat4.xml	2022-05-21 15:09:19.511995+02	99	EXECUTED	7:7d441044b89ac1bf281d44832a454fbf	sql (x2), dropColumn		\N	3.1.1
2015030301	Maxim Valyanskiy	sql/updates/2015-03-03-remove-topics-stat2.xml	2022-05-21 15:09:19.526668+02	100	EXECUTED	7:5473f7e7cd33fe7b5ee63520ec302495	sql (x2), dropColumn		\N	3.1.1
2015041301	Maxim Valyanskiy	sql/updates/2015-04-13-user-remarks-fkey.xml	2022-05-21 15:09:19.54186+02	101	EXECUTED	7:a4bb8ae95c6fb4e5ef097da8e153b02a	sql		\N	3.1.1
2015081801	Maxim Valyanskiy	sql/updates/2015-08-18-image-name-idx.xml	2022-05-21 15:09:19.560133+02	102	EXECUTED	7:8592ca86549a6985d60da16157a6e894	createIndex		\N	3.1.1
2015102901	Maxim Valyanskiy	sql/updates/2015-10-29-drop-jamwiki.xml	2022-05-21 15:09:19.609655+02	103	EXECUTED	7:a331e02be6653a836478f1a7f69426df	dropView (x3), dropSequence (x9), dropTable (x16)		\N	3.1.1
2015102902	Maxim Valyanskiy	sql/updates/2015-10-29-drop-jamwiki.xml	2022-05-21 15:09:19.627129+02	104	EXECUTED	7:7d67c4e532a2ffa3cb8a50c1bee60512	dropTable (x2)		\N	3.1.1
2015102903	Maxim Valyanskiy	sql/updates/2015-10-29-drop-jamwiki.xml	2022-05-21 15:09:19.641194+02	105	EXECUTED	7:f3b3f2ff0d231c4714e21a594fcaa306	dropView, dropTable		\N	3.1.1
2015102910	Maxim Valyanskiy	sql/updates/2015-10-29-drop-unused-idx.xml	2022-05-21 15:09:19.654318+02	106	EXECUTED	7:ae4ad07d4b1ae0930d4c28cccc2868a2	dropIndex		\N	3.1.1
2015103101	Maxim Valyanskiy	sql/updates/2015-10-31-drop-jamwiki.xml	2022-05-21 15:09:19.667576+02	107	EXECUTED	7:63cb5015925b304b04c817659134f863	sql		\N	3.1.1
2015111101	Maxim Valyanskiy	sql/updates/2015-11-11-events-idx.xml	2022-05-21 15:09:19.685458+02	108	EXECUTED	7:ec54b58929b1f32f4c1c50c8341f92ce	dropIndex, createIndex		\N	3.1.1
2016012801	Maxim Valyanskiy	sql/updates/2016-01-28-fuzzystrmatch.xml	2022-05-21 15:09:19.699745+02	109	EXECUTED	7:d78cfb3d6da1e03fc5ed8619b56e00c1	sql		\N	3.1.1
2017021701	Maxim Valyanskiy	sql/updates/2017-02-27-images-table.xml	2022-05-21 15:09:19.714245+02	110	EXECUTED	7:7222441b5f267686e7c0b98bff86ea67	addColumn, sql, dropColumn (x2), addNotNullConstraint		\N	3.1.1
2017102802	Maxim Valyanskiy	sql/updates/2017-10-28-branch-authors.xml	2022-05-21 15:09:19.731245+02	111	EXECUTED	7:a39ceda7c7822453d03e25f119ca4038	sql		\N	3.1.1
2017111301	Mikhail Klementev	sql/updates/2017-11-13-force-unlogin.xml	2022-05-21 15:09:19.744937+02	112	EXECUTED	7:3ff8c9bf5101386cafd5948641bf1564	addColumn		\N	3.1.1
2018050601	Maxim Valyanskiy	sql/updates/2018-05-06-imagepost.xml	2022-05-21 15:09:19.758799+02	113	EXECUTED	7:a70bcda65852912726d656c7d220b765	dropForeignKeyConstraint		\N	3.1.1
2018050602	Maxim Valyanskiy	sql/updates/2018-05-06-imagepost.xml	2022-05-21 15:09:19.77273+02	114	EXECUTED	7:d38ecb7c5c77d7fd99dacbcf139af92c	dropUniqueConstraint		\N	3.1.1
2018050603	Maxim Valyanskiy	sql/updates/2018-05-06-imagepost.xml	2022-05-21 15:09:19.790047+02	115	EXECUTED	7:a3c6aa300ab12b2a84e5eb9f96ce4f6c	createIndex		\N	3.1.1
2018102801	Mikhail Klementev	sql/updates/2018-10-28-deleted.xml	2022-05-21 15:09:19.803637+02	116	EXECUTED	7:4604a10f3249718502c5cde1adfc06f3	insert		\N	3.1.1
2019051201	Mikhail Klementev	sql/updates/2019-05-12-grant-deleted.xml	2022-05-21 15:09:19.816651+02	117	EXECUTED	7:58f913dc89df029d99767c18f91ff725	sql		\N	3.1.1
2019051201	Maxim Valyanskiy	sql/updates/2019-11-28-lastmod-notnull.xml	2022-05-21 15:09:19.829677+02	118	EXECUTED	7:7e0d1271d3fb4e44dcb8af5b07f7b0fa	addNotNullConstraint		\N	3.1.1
2019051201	Maxim Valyanskiy	sql/updates/2020-01-02-no-anon.xml	2022-05-21 15:09:19.84303+02	119	EXECUTED	7:879c143ee01ea4a42dac389e13461903	addColumn		\N	3.1.1
2021011701	Maxim Valyanskiy	sql/updates/2021-01-17-poll-history.xml	2022-05-21 15:09:19.85641+02	120	EXECUTED	7:da277786320b49fab4bfe7354c66543f	addColumn		\N	3.1.1
2021031001	Maxim Valyanskiy	sql/updates/2021-03-10-telegram.xml	2022-05-21 15:09:19.879595+02	121	EXECUTED	7:5c533fafc3afed2dcda8d68484ae1a6f	createTable, createIndex		\N	3.1.1
2021031002	Maxim Valyanskiy	sql/updates/2021-03-10-telegram.xml	2022-05-21 15:09:19.893287+02	122	EXECUTED	7:ac629ff6e5593c3c5ba3b30e92bb7aaa	sql		\N	3.1.1
2021032101	Maxim Valyanskiy	sql/updates/2021-03-10-telegram.xml	2022-05-21 15:09:19.906194+02	123	EXECUTED	7:6734914d81f1411213fbccda6736d442	sql		\N	3.1.1
2021081101	Konstantin Ivanov	sql/updates/2021-08-11-frozen-users.xml	2022-05-21 15:09:19.921259+02	124	EXECUTED	7:ddd98e52e2079e5022099de0e41c8868	addColumn		\N	3.1.1
2021081102	Konstantin Ivanov	sql/updates/2021-08-11-frozen-users.xml	2022-05-21 15:09:19.938763+02	125	EXECUTED	7:131da469660609877386dd5d4d03b347	sql		\N	3.1.1
2021120801	linuxtalks	sql/updates/2021-12-09-missing-index.xml	2022-05-21 15:09:19.983859+02	126	EXECUTED	7:38ca5c40a2907a193cdce6106ccd301b	createIndex (x7)		\N	3.1.1
2021121405	linuxtalks	sql/updates/2021-12-14-email-normalize.xml	2022-05-21 15:09:19.998507+02	127	EXECUTED	7:6384d7ba6afa5e1f180dcadcea955840	sql		\N	3.1.1
2021121451	linuxtalks	sql/updates/2021-12-14-email-normalize.xml	2022-05-21 15:09:20.026883+02	128	EXECUTED	7:55c08d0ea6f9c88eef3366fc0ce74dcb	sql		\N	3.1.1
2021121701	Maxim Valynskiy	sql/updates/2021-12-17-fix-user-delete.xml	2022-05-21 15:09:20.039676+02	129	EXECUTED	7:04933fb4f4b4a59100dc123b3af607c9	sql		\N	3.1.1
2022032601	Maxim Valyanskiy	sql/updates/2022-03-26-trigger-to-code.xml	2022-05-21 15:09:20.052925+02	130	EXECUTED	7:6c70caeb19c0cb89eaea5ab2b3897649	sql		\N	3.1.1
2022040301	Maxim Valyanskiy	sql/updates/2022-04-03-invites.xml	2022-05-21 15:09:20.076869+02	131	EXECUTED	7:a6de51b5c7e62e29122848d4109dd68b	createTable		\N	3.1.1
2022040303	Maxim Valyanskiy	sql/updates/2022-04-03-invites.xml	2022-05-21 15:09:20.091275+02	132	EXECUTED	7:5e33fcde72a42bdb09d12dc9436a9cbd	addColumn		\N	3.1.1
2022040304	Maxim Valyanskiy	sql/updates/2022-04-03-invites.xml	2022-05-21 15:09:20.104709+02	133	EXECUTED	7:d50d3db50e55c3de413c50f5b5b7a7c9	sql		\N	3.1.1
2022040305	Maxim Valyanskiy	sql/updates/2022-04-03-invites.xml	2022-05-21 15:09:20.141046+02	134	EXECUTED	7:87c5db9fad4af46f91681486a7e815be	sql		\N	3.1.1
\.


--
-- Data for Name: databasechangeloglock; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.databasechangeloglock (id, locked, lockgranted, lockedby) FROM stdin;
1	f	\N	\N
\.


--
-- Data for Name: del_info; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.del_info (msgid, delby, reason, deldate, bonus) FROM stdin;
\.


--
-- Data for Name: edit_info; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.edit_info (id, msgid, editor, oldmessage, editdate, oldtitle, oldtags, oldlinktext, oldurl, object_type, oldminor, oldimage, oldpoll) FROM stdin;
\.


--
-- Data for Name: groups; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.groups (id, title, image, section, stat3, restrict_topics, info, restrict_comments, longinfo, resolvable, urlname) FROM stdin;
126	General	\N	2	0	\N	общий форум для технических вопросов, не подходящих в другие группы <i>[<a href="/wiki/en/lor-faq">faq</a>]</i>	-9999	\N	t	general
4962	Скриншоты	\N	3	0	\N	\N	-9999	\N	f	screenshots
19387	Голосования	\N	5	0	\N	\N	-9999	\N	f	polls
19390	Клуб	\N	2	0	10000	\N	-1	\N	f	club
2	linuxtalks.co	/img/angry-logo.png	1	0	\N	новости и объявления о работе сервера linuxtalks.co	-9999	\N	f	linuxtalks-co
4068	Linuxtalks-co	\N	2	0	\N	комментарии по работе и предложения по развитию сервера linuxtalks.co	-50	\N	t	linuxtalks-co
\.


--
-- Data for Name: ignore_list; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.ignore_list (userid, ignored) FROM stdin;
\.


--
-- Data for Name: images; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.images (id, topic, deleted, extension) FROM stdin;
\.


--
-- Data for Name: memories; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.memories (id, userid, topic, add_date, watch) FROM stdin;
\.


--
-- Data for Name: monthly_stats; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.monthly_stats (section, year, month, c, groupid) FROM stdin;
\.


--
-- Data for Name: msgbase; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.msgbase (id, message, markup) FROM stdin;
\.


--
-- Data for Name: polls; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.polls (id, topic, multiselect) FROM stdin;
\.


--
-- Data for Name: polls_variants; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.polls_variants (id, vote, label, votes) FROM stdin;
\.


--
-- Data for Name: sections; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.sections (id, name, moderate, imagepost, linktext, havelink, expire, vote, add_info, scroll_mode, restrict_topics, imageallowed) FROM stdin;
1	Новости	t	f	Подробности	t	4 years	f	<H1>Добавить Новость</H1>\n\n\nПожалуйста, соблюдайте эти правила при написании новостей:\n<ul>\n<li>Текст новости должен быть написан на русском языке. Допускается (но\nне рекомендуется) использование английского языка при перечислении\nсписка изменений. Однако, не допускается языковая "каша",\nиспользование в одном предложении слов и выражений на разных языках.\nТранслит не допускается. Использование других иностранных языков\n(немецкого, украинского и др) не допускается. Это правило не касается \nназваний продуктов (их переводить не нужно).</li>\n<li>Из текста новости должно быть ясно, о чем она. Если вы пишете\nновость о выходе новой версии программы - напишите пару слов о самой\nпрограмме.</li>\n<li>Текст должен быть кратким, рекомендуемый размер 3-5 строк.</li>\n<li>По умолчанию у нас установлен режим автовыделения ссылок в тексте\nновости. Если вы хотите выделять ссылки вручную HTML тегами - не забудьте\nпереключиться с режима "<em>Plain Text</em>" на "<em>HTML</em>"\n<li>Новость без ссылки - не новость (за небольшим исключением).\n<li>Нельзя задавать вопросов в новостях - используйте <a href="view-section.jsp?section=2">форум</a>.\n<li>Запрещается преднамеренное нарушение правил русского языка, искажение слов</li>\n<li> Не забывайте про заполнения поля Subject. Заголовок новости может\nбыть изменен модератором</li>\n<li>Не ссылайтесь на заглавие новости, лучше повторите его.</li>\n<li>Нельзя копировать один-в-один новости с других сайтов, если они\nявным образом не разрешают это.</li>\n<li>Выберите подходящую группу для новости. Группа может быть изменена модератором</li>\n<li>Новость должна быть информационной. Мы не размещаем рекламных\nсообщений в новостях</li>\n</ul>\nСпасибо!\n	SECTION	-50	t
2	Форум	f	f	\N	f	4 years	f	<h1>Добавить тему в форум</h1>\n\nПросьба ко всем, добавляющим темы в форум:\n<ul>\n<li><b>Прочитайте <a href="faq.jsp">FAQ</a></b>! Возможно, ваш вопрос уже содержится в нашем сборнике ответов на часто задаваемые вопросы.\n<li><b>Пишите в правильный форум!</b> Выберите подходящий по теме вашего вопроса раздел форума, например\nвопросы по администрированию системы нужно задавать в Admin, а\nне в General и т.п.\n<li><b>Пишите осмысленный заголовок</b>. Придумайте осмысленный заголовок теме. Сообщения с бессмысленными загловками ("Помогите!", "Вопрос", ...), как правило, остаются без ответа.\n</ul>	GROUP	-50	f
3	Галерея	t	t	\N	f	4 years	f	\N	SECTION	-50	f
5	Голосования	t	f	\N	f	4 years	t	\N	SECTION	-50	f
\.


--
-- Data for Name: tags; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.tags (msgid, tagid) FROM stdin;
\.


--
-- Data for Name: tags_values; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.tags_values (id, counter, value) FROM stdin;
\.


--
-- Data for Name: telegram_posts; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.telegram_posts (topic_id, telegram_id, postdate) FROM stdin;
\.


--
-- Data for Name: topic_users_notified; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.topic_users_notified (topic, userid) FROM stdin;
\.


--
-- Data for Name: topics; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.topics (id, groupid, userid, title, url, moderate, postdate, linktext, deleted, stat1, stat3, lastmod, commitby, notop, commitdate, postscore, postip, sticky, ua_id, resolved, minor, draft, allow_anonymous) FROM stdin;
\.


--
-- Data for Name: user_agents; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.user_agents (id, name) FROM stdin;
\.


--
-- Data for Name: user_events; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.user_events (userid, type, private, event_date, message_id, comment_id, message, unread, id) FROM stdin;
\.


--
-- Data for Name: user_invites; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.user_invites (invite_code, owner, issue_date, invited_user, email, valid_until) FROM stdin;
\.


--
-- Data for Name: user_log; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.user_log (id, userid, action_userid, action_date, action, info) FROM stdin;
\.


--
-- Data for Name: user_remarks; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.user_remarks (id, user_id, ref_user_id, remark_text) FROM stdin;
\.


--
-- Data for Name: user_settings; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.user_settings (id, settings, main) FROM stdin;
\.


--
-- Data for Name: user_tags; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.user_tags (user_id, tag_id, is_favorite) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.users (id, name, nick, passwd, url, email, canmod, photo, town, candel, lostpwd, blocked, score, max_score, lastlogin, regdate, activated, corrector, userinfo, unread_events, new_email, style, token_generation, frozen_until, frozen_by, freezing_reason) FROM stdin;
3	Deleted	Deleted	\N	\N	\N	f	\N	\N	f	1970-01-01 01:00:00+01	\N	\N	\N	\N	\N	t	f	\N	0	\N	tango	0	\N	\N	\N
2	Anonymous	anonymous	\N	\N		f	\N	\N	f	1970-01-01 01:00:00+01	f	-117654	4	\N	\N	t	f	\N	0	\N	tango	0	\N	\N	\N
1	cocucka	cocucka	UEX2F5/8Q5loMT3EQaknMyNbSxtlgain	\N	cocucka@pmail.pw	t	\N	\N	t	1970-01-01 01:00:00+01	f	500	500	2022-05-21 15:16:00.747112+02	\N	t	f	\N	0	\N	tango	0	\N	\N	\N
\.


--
-- Data for Name: vote_users; Type: TABLE DATA; Schema: public; Owner: linuxtalks
--

COPY public.vote_users (vote, userid, variant_id) FROM stdin;
\.


--
-- Name: edit_info_id_seq; Type: SEQUENCE SET; Schema: public; Owner: linuxtalks
--

SELECT pg_catalog.setval('public.edit_info_id_seq', 1, false);


--
-- Name: images_id_seq; Type: SEQUENCE SET; Schema: public; Owner: linuxtalks
--

SELECT pg_catalog.setval('public.images_id_seq', 1, false);


--
-- Name: memories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: linuxtalks
--

SELECT pg_catalog.setval('public.memories_id_seq', 1, false);


--
-- Name: s_guid; Type: SEQUENCE SET; Schema: public; Owner: linuxtalks
--

SELECT pg_catalog.setval('public.s_guid', 1, false);


--
-- Name: s_msg; Type: SEQUENCE SET; Schema: public; Owner: linuxtalks
--

SELECT pg_catalog.setval('public.s_msg', 1, false);


--
-- Name: s_msgid; Type: SEQUENCE SET; Schema: public; Owner: linuxtalks
--

SELECT pg_catalog.setval('public.s_msgid', 1, false);


--
-- Name: s_uid; Type: SEQUENCE SET; Schema: public; Owner: linuxtalks
--

SELECT pg_catalog.setval('public.s_uid', 1, false);


--
-- Name: tags_values_id_seq; Type: SEQUENCE SET; Schema: public; Owner: linuxtalks
--

SELECT pg_catalog.setval('public.tags_values_id_seq', 1, false);


--
-- Name: user_agents_id_seq; Type: SEQUENCE SET; Schema: public; Owner: linuxtalks
--

SELECT pg_catalog.setval('public.user_agents_id_seq', 1, false);


--
-- Name: user_events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: linuxtalks
--

SELECT pg_catalog.setval('public.user_events_id_seq', 1, false);


--
-- Name: user_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: linuxtalks
--

SELECT pg_catalog.setval('public.user_log_id_seq', 1, false);


--
-- Name: user_remarks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: linuxtalks
--

SELECT pg_catalog.setval('public.user_remarks_id_seq', 1, false);


--
-- Name: vote_id; Type: SEQUENCE SET; Schema: public; Owner: linuxtalks
--

SELECT pg_catalog.setval('public.vote_id', 1, false);


--
-- Name: votes_id; Type: SEQUENCE SET; Schema: public; Owner: linuxtalks
--

SELECT pg_catalog.setval('public.votes_id', 1, false);


--
-- Name: ban_info ban_info_pkey; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.ban_info
    ADD CONSTRAINT ban_info_pkey PRIMARY KEY (userid);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);

ALTER TABLE public.comments CLUSTER ON comments_pkey;


--
-- Name: del_info del_info_pkey; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.del_info
    ADD CONSTRAINT del_info_pkey PRIMARY KEY (msgid);


--
-- Name: edit_info edit_info_pkey; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.edit_info
    ADD CONSTRAINT edit_info_pkey PRIMARY KEY (id);


--
-- Name: groups groups_pkey; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);


--
-- Name: ignore_list ignore_list_pkey; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.ignore_list
    ADD CONSTRAINT ignore_list_pkey PRIMARY KEY (userid, ignored);


--
-- Name: memories memories_pkey; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.memories
    ADD CONSTRAINT memories_pkey PRIMARY KEY (id);


--
-- Name: msgbase msgbase_pkey; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.msgbase
    ADD CONSTRAINT msgbase_pkey PRIMARY KEY (id);


--
-- Name: databasechangeloglock pk_databasechangeloglock; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.databasechangeloglock
    ADD CONSTRAINT pk_databasechangeloglock PRIMARY KEY (id);


--
-- Name: images pk_images; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT pk_images PRIMARY KEY (id);


--
-- Name: telegram_posts pk_telegram_posts; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.telegram_posts
    ADD CONSTRAINT pk_telegram_posts PRIMARY KEY (telegram_id);


--
-- Name: user_invites pk_user_invites; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_invites
    ADD CONSTRAINT pk_user_invites PRIMARY KEY (invite_code);


--
-- Name: user_remarks pk_user_remarks; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_remarks
    ADD CONSTRAINT pk_user_remarks PRIMARY KEY (id);


--
-- Name: sections sections_pkey; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.sections
    ADD CONSTRAINT sections_pkey PRIMARY KEY (id);


--
-- Name: tags tags_msgid_key; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_msgid_key UNIQUE (msgid, tagid);


--
-- Name: tags_values tags_values_pkey; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.tags_values
    ADD CONSTRAINT tags_values_pkey PRIMARY KEY (id);


--
-- Name: tags_values tags_values_value_key; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.tags_values
    ADD CONSTRAINT tags_values_value_key UNIQUE (value);


--
-- Name: user_agents user_agents_name_key; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_agents
    ADD CONSTRAINT user_agents_name_key UNIQUE (name);


--
-- Name: user_agents user_agents_pkey; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_agents
    ADD CONSTRAINT user_agents_pkey PRIMARY KEY (id);


--
-- Name: user_events user_events_pkey; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_events
    ADD CONSTRAINT user_events_pkey PRIMARY KEY (id);


--
-- Name: user_log user_log_pkey; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_log
    ADD CONSTRAINT user_log_pkey PRIMARY KEY (id);


--
-- Name: user_settings user_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_settings
    ADD CONSTRAINT user_settings_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: polls votenames_pkey; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.polls
    ADD CONSTRAINT votenames_pkey PRIMARY KEY (id);


--
-- Name: polls_variants votes_pkey; Type: CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.polls_variants
    ADD CONSTRAINT votes_pkey PRIMARY KEY (id);


--
-- Name: bips_ip; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE UNIQUE INDEX bips_ip ON public.b_ips USING btree (ip);


--
-- Name: comment_authordate; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX comment_authordate ON public.comments USING btree (userid, postdate);


--
-- Name: comment_reply2; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX comment_reply2 ON public.comments USING btree (replyto) WHERE (replyto IS NOT NULL);


--
-- Name: comment_topic; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX comment_topic ON public.comments USING btree (topic);


--
-- Name: comment_tracker; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX comment_tracker ON public.comments USING btree (topic, postdate DESC) WHERE (NOT deleted);


--
-- Name: comments_editor_id_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX comments_editor_id_idx ON public.comments USING btree (editor_id);


--
-- Name: comments_postip; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX comments_postip ON public.comments USING btree (postip);


--
-- Name: commit_order2; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX commit_order2 ON public.topics USING btree (commitdate DESC) WHERE (commitdate IS NOT NULL);


--
-- Name: commit_order3; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX commit_order3 ON public.topics USING btree (groupid, commitdate DESC) WHERE (commitdate IS NOT NULL);


--
-- Name: del_info_date; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX del_info_date ON public.del_info USING btree (deldate DESC) WHERE (deldate IS NOT NULL);


--
-- Name: del_info_delby; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX del_info_delby ON public.del_info USING btree (delby);


--
-- Name: edit_info_editor_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX edit_info_editor_idx ON public.edit_info USING btree (editor);


--
-- Name: edit_info_msgid; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX edit_info_msgid ON public.edit_info USING btree (msgid);


--
-- Name: group_section; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX group_section ON public.groups USING btree (section);


--
-- Name: groups_urlname; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX groups_urlname ON public.groups USING btree (urlname);


--
-- Name: groups_urlname_u; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE UNIQUE INDEX groups_urlname_u ON public.groups USING btree (urlname, section);


--
-- Name: i_nick; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE UNIQUE INDEX i_nick ON public.users USING btree (nick);


--
-- Name: i_votes_vote; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX i_votes_vote ON public.polls_variants USING btree (vote);


--
-- Name: ignore_list_ignored_key; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX ignore_list_ignored_key ON public.ignore_list USING btree (ignored);


--
-- Name: image_topic_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX image_topic_idx ON public.images USING btree (topic);


--
-- Name: memories_topic_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX memories_topic_idx ON public.memories USING btree (topic);


--
-- Name: memories_un; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE UNIQUE INDEX memories_un ON public.memories USING btree (userid, topic, watch);


--
-- Name: refuser_remarks_tagid_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX refuser_remarks_tagid_idx ON public.user_remarks USING btree (ref_user_id);


--
-- Name: tags_msgid; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX tags_msgid ON public.tags USING btree (msgid);


--
-- Name: tags_tagid; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX tags_tagid ON public.tags USING btree (tagid);


--
-- Name: tags_values_prefix_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX tags_values_prefix_idx ON public.tags_values USING btree (value text_pattern_ops);


--
-- Name: tags_values_top; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX tags_values_top ON public.tags_values USING btree (id) WHERE (counter >= 10);


--
-- Name: telegram_topic_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX telegram_topic_idx ON public.telegram_posts USING btree (topic_id);


--
-- Name: topic_author; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX topic_author ON public.topics USING btree (userid);


--
-- Name: topic_deleted; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX topic_deleted ON public.topics USING btree (id) WHERE deleted;


--
-- Name: topic_group; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX topic_group ON public.topics USING btree (groupid);


--
-- Name: topic_postip; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX topic_postip ON public.topics USING btree (postip);


--
-- Name: topic_users_notified_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE UNIQUE INDEX topic_users_notified_idx ON public.topic_users_notified USING btree (topic, userid);


--
-- Name: topic_users_notified_userid_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX topic_users_notified_userid_idx ON public.topic_users_notified USING btree (userid);


--
-- Name: topics_commitby_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX topics_commitby_idx ON public.topics USING btree (commitby);


--
-- Name: topics_date; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX topics_date ON public.topics USING btree (postdate);


--
-- Name: topics_lastmod; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX topics_lastmod ON public.topics USING btree (lastmod DESC) WHERE (NOT deleted);


--
-- Name: topics_pkey; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE UNIQUE INDEX topics_pkey ON public.topics USING btree (id);


--
-- Name: topics_sticky_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX topics_sticky_idx ON public.topics USING btree (groupid, id DESC) WHERE (sticky AND (NOT deleted));


--
-- Name: user_events_comment; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX user_events_comment ON public.user_events USING btree (comment_id);


--
-- Name: user_events_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX user_events_idx ON public.user_events USING btree (userid);


--
-- Name: user_events_topic; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX user_events_topic ON public.user_events USING btree (message_id);


--
-- Name: user_log_action_userid_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX user_log_action_userid_idx ON public.user_log USING btree (action_userid);


--
-- Name: user_log_userid_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX user_log_userid_idx ON public.user_log USING btree (userid);


--
-- Name: user_remarks_userid_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX user_remarks_userid_idx ON public.user_remarks USING btree (user_id);


--
-- Name: user_tags_tagid_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX user_tags_tagid_idx ON public.user_tags USING btree (tag_id);


--
-- Name: user_tags_uniq_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE UNIQUE INDEX user_tags_uniq_idx ON public.user_tags USING btree (user_id, tag_id, is_favorite);


--
-- Name: user_tags_userid_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX user_tags_userid_idx ON public.user_tags USING btree (user_id);


--
-- Name: users_email_normalized_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX users_email_normalized_idx ON public.users USING btree (public.normalize_email((email)::text));


--
-- Name: users_frozen_by_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX users_frozen_by_idx ON public.users USING btree (frozen_by);


--
-- Name: users_unactivated_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX users_unactivated_idx ON public.users USING btree (id) WHERE (NOT activated);


--
-- Name: vote_users_idx; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE UNIQUE INDEX vote_users_idx ON public.vote_users USING btree (vote, userid, variant_id);


--
-- Name: vote_users_user; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE INDEX vote_users_user ON public.vote_users USING btree (userid);


--
-- Name: votenames_topic_key; Type: INDEX; Schema: public; Owner: linuxtalks
--

CREATE UNIQUE INDEX votenames_topic_key ON public.polls USING btree (topic);


--
-- Name: comments comins_t; Type: TRIGGER; Schema: public; Owner: linuxtalks
--

CREATE TRIGGER comins_t AFTER INSERT ON public.comments FOR EACH ROW EXECUTE FUNCTION public.comins();


--
-- Name: del_info event_delete_t; Type: TRIGGER; Schema: public; Owner: linuxtalks
--

CREATE TRIGGER event_delete_t AFTER INSERT ON public.del_info FOR EACH ROW EXECUTE FUNCTION public.event_delete();


--
-- Name: del_info msgdel_t; Type: TRIGGER; Schema: public; Owner: linuxtalks
--

CREATE TRIGGER msgdel_t AFTER INSERT ON public.del_info FOR EACH ROW EXECUTE FUNCTION public.msgdel();


--
-- Name: del_info msgundel_t; Type: TRIGGER; Schema: public; Owner: linuxtalks
--

CREATE TRIGGER msgundel_t AFTER DELETE ON public.del_info FOR EACH ROW EXECUTE FUNCTION public.msgundel();


--
-- Name: user_events new_event_t; Type: TRIGGER; Schema: public; Owner: linuxtalks
--

CREATE TRIGGER new_event_t AFTER INSERT ON public.user_events FOR EACH ROW EXECUTE FUNCTION public.new_event();


--
-- Name: topics topins_t; Type: TRIGGER; Schema: public; Owner: linuxtalks
--

CREATE TRIGGER topins_t AFTER INSERT ON public.topics FOR EACH ROW EXECUTE FUNCTION public.topins();


--
-- Name: ban_info ban_info_ban_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.ban_info
    ADD CONSTRAINT ban_info_ban_by_fkey FOREIGN KEY (ban_by) REFERENCES public.users(id);


--
-- Name: ban_info ban_info_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.ban_info
    ADD CONSTRAINT ban_info_userid_fkey FOREIGN KEY (userid) REFERENCES public.users(id);


--
-- Name: comments comments_editor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_editor_id_fkey FOREIGN KEY (editor_id) REFERENCES public.users(id);


--
-- Name: comments comments_replyto_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_replyto_fkey FOREIGN KEY (replyto) REFERENCES public.comments(id);


--
-- Name: comments comments_topic_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_topic_fkey FOREIGN KEY (topic) REFERENCES public.topics(id);


--
-- Name: comments comments_ua_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_ua_id_fkey FOREIGN KEY (ua_id) REFERENCES public.user_agents(id);


--
-- Name: comments comments_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_userid_fkey FOREIGN KEY (userid) REFERENCES public.users(id);


--
-- Name: del_info del_info_delby_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.del_info
    ADD CONSTRAINT del_info_delby_fkey FOREIGN KEY (delby) REFERENCES public.users(id);


--
-- Name: edit_info edit_info_editor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.edit_info
    ADD CONSTRAINT edit_info_editor_fkey FOREIGN KEY (editor) REFERENCES public.users(id);


--
-- Name: edit_info edit_info_msgid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.edit_info
    ADD CONSTRAINT edit_info_msgid_fkey FOREIGN KEY (msgid) REFERENCES public.msgbase(id);


--
-- Name: groups groups_section_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_section_fkey FOREIGN KEY (section) REFERENCES public.sections(id);


--
-- Name: ignore_list ignore_list_ignored_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.ignore_list
    ADD CONSTRAINT ignore_list_ignored_fkey FOREIGN KEY (ignored) REFERENCES public.users(id);


--
-- Name: ignore_list ignore_list_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.ignore_list
    ADD CONSTRAINT ignore_list_userid_fkey FOREIGN KEY (userid) REFERENCES public.users(id);


--
-- Name: images images_topic_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT images_topic_fkey FOREIGN KEY (topic) REFERENCES public.topics(id);


--
-- Name: memories memories_topic_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.memories
    ADD CONSTRAINT memories_topic_fkey FOREIGN KEY (topic) REFERENCES public.topics(id);


--
-- Name: memories memories_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.memories
    ADD CONSTRAINT memories_userid_fkey FOREIGN KEY (userid) REFERENCES public.users(id);


--
-- Name: monthly_stats monthly_stats_section_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.monthly_stats
    ADD CONSTRAINT monthly_stats_section_fkey FOREIGN KEY (section) REFERENCES public.sections(id);


--
-- Name: user_remarks refuser_remarks_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_remarks
    ADD CONSTRAINT refuser_remarks_userid_fkey FOREIGN KEY (ref_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: tags tags_msgid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_msgid_fkey FOREIGN KEY (msgid) REFERENCES public.topics(id);


--
-- Name: tags tags_tagid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_tagid_fkey FOREIGN KEY (tagid) REFERENCES public.tags_values(id);


--
-- Name: telegram_posts telegram_posts_topic_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.telegram_posts
    ADD CONSTRAINT telegram_posts_topic_fkey FOREIGN KEY (topic_id) REFERENCES public.topics(id);


--
-- Name: topic_users_notified topic_users_notified_topic_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.topic_users_notified
    ADD CONSTRAINT topic_users_notified_topic_fkey FOREIGN KEY (topic) REFERENCES public.topics(id);


--
-- Name: topic_users_notified topic_users_notified_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.topic_users_notified
    ADD CONSTRAINT topic_users_notified_user_fkey FOREIGN KEY (userid) REFERENCES public.users(id);


--
-- Name: topics topics_commitby_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.topics
    ADD CONSTRAINT topics_commitby_fkey FOREIGN KEY (commitby) REFERENCES public.users(id);


--
-- Name: topics topics_groupid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.topics
    ADD CONSTRAINT topics_groupid_fkey FOREIGN KEY (groupid) REFERENCES public.groups(id);


--
-- Name: topics topics_ua_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.topics
    ADD CONSTRAINT topics_ua_id_fkey FOREIGN KEY (ua_id) REFERENCES public.user_agents(id);


--
-- Name: topics topics_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.topics
    ADD CONSTRAINT topics_userid_fkey FOREIGN KEY (userid) REFERENCES public.users(id);


--
-- Name: user_events user_events_comment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_events
    ADD CONSTRAINT user_events_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.comments(id);


--
-- Name: user_events user_events_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_events
    ADD CONSTRAINT user_events_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.topics(id);


--
-- Name: user_events user_events_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_events
    ADD CONSTRAINT user_events_userid_fkey FOREIGN KEY (userid) REFERENCES public.users(id);


--
-- Name: user_invites user_invites_invited_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_invites
    ADD CONSTRAINT user_invites_invited_fkey FOREIGN KEY (invited_user) REFERENCES public.users(id);


--
-- Name: user_invites user_invites_owner_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_invites
    ADD CONSTRAINT user_invites_owner_fkey FOREIGN KEY (owner) REFERENCES public.users(id);


--
-- Name: user_log user_log_action_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_log
    ADD CONSTRAINT user_log_action_userid_fkey FOREIGN KEY (action_userid) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_log user_log_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_log
    ADD CONSTRAINT user_log_userid_fkey FOREIGN KEY (userid) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_remarks user_remarks_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_remarks
    ADD CONSTRAINT user_remarks_userid_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_settings user_settings_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_settings
    ADD CONSTRAINT user_settings_id_fkey FOREIGN KEY (id) REFERENCES public.users(id);


--
-- Name: user_tags user_tags_tagid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_tags
    ADD CONSTRAINT user_tags_tagid_fkey FOREIGN KEY (tag_id) REFERENCES public.tags_values(id);


--
-- Name: user_tags user_tags_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.user_tags
    ADD CONSTRAINT user_tags_userid_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: users users_frozen_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_frozen_by_fkey FOREIGN KEY (frozen_by) REFERENCES public.users(id);


--
-- Name: vote_users vote_users_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.vote_users
    ADD CONSTRAINT vote_users_userid_fkey FOREIGN KEY (userid) REFERENCES public.users(id);


--
-- Name: vote_users vote_users_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.vote_users
    ADD CONSTRAINT vote_users_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.polls_variants(id);


--
-- Name: vote_users vote_users_vote_fkey; Type: FK CONSTRAINT; Schema: public; Owner: linuxtalks
--

ALTER TABLE ONLY public.vote_users
    ADD CONSTRAINT vote_users_vote_fkey FOREIGN KEY (vote) REFERENCES public.polls(id);


--
-- Name: TABLE b_ips; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.b_ips TO linuxtalks;


--
-- Name: TABLE ban_info; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT ALL ON TABLE public.ban_info TO linuxtalks;


--
-- Name: TABLE comments; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.comments TO linuxtalks;


--
-- Name: TABLE del_info; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.del_info TO linuxtalks;


--
-- Name: TABLE edit_info; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.edit_info TO linuxtalks;


--
-- Name: SEQUENCE edit_info_id_seq; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,UPDATE ON SEQUENCE public.edit_info_id_seq TO linuxtalks;


--
-- Name: TABLE groups; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.groups TO linuxtalks;


--
-- Name: TABLE ignore_list; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT ALL ON TABLE public.ignore_list TO linuxtalks;


--
-- Name: TABLE images; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.images TO linuxtalks;


--
-- Name: SEQUENCE images_id_seq; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT UPDATE ON SEQUENCE public.images_id_seq TO linuxtalks;


--
-- Name: TABLE memories; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT ALL ON TABLE public.memories TO linuxtalks;


--
-- Name: SEQUENCE memories_id_seq; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,UPDATE ON SEQUENCE public.memories_id_seq TO linuxtalks;


--
-- Name: TABLE monthly_stats; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT ALL ON TABLE public.monthly_stats TO linuxtalks;


--
-- Name: TABLE msgbase; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.msgbase TO linuxtalks;


--
-- Name: TABLE polls; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.polls TO linuxtalks;


--
-- Name: TABLE polls_variants; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.polls_variants TO linuxtalks;


--
-- Name: SEQUENCE s_guid; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,UPDATE ON SEQUENCE public.s_guid TO linuxtalks;


--
-- Name: SEQUENCE s_msgid; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT ALL ON SEQUENCE public.s_msgid TO linuxtalks;


--
-- Name: SEQUENCE s_uid; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,UPDATE ON SEQUENCE public.s_uid TO linuxtalks;


--
-- Name: TABLE sections; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,DELETE,UPDATE ON TABLE public.sections TO linuxtalks;


--
-- Name: TABLE tags; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT ALL ON TABLE public.tags TO linuxtalks;


--
-- Name: TABLE tags_values; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.tags_values TO linuxtalks;


--
-- Name: SEQUENCE tags_values_id_seq; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT UPDATE ON SEQUENCE public.tags_values_id_seq TO linuxtalks;


--
-- Name: TABLE telegram_posts; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,INSERT,DELETE ON TABLE public.telegram_posts TO linuxtalks;


--
-- Name: TABLE topic_users_notified; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,INSERT,DELETE ON TABLE public.topic_users_notified TO linuxtalks;


--
-- Name: TABLE topics; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.topics TO linuxtalks;


--
-- Name: TABLE user_agents; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,INSERT ON TABLE public.user_agents TO linuxtalks;


--
-- Name: SEQUENCE user_agents_id_seq; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT UPDATE ON SEQUENCE public.user_agents_id_seq TO linuxtalks;


--
-- Name: TABLE user_events; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.user_events TO linuxtalks;


--
-- Name: SEQUENCE user_events_id_seq; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT ALL ON SEQUENCE public.user_events_id_seq TO linuxtalks;


--
-- Name: TABLE user_invites; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.user_invites TO linuxtalks;


--
-- Name: TABLE user_log; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,INSERT ON TABLE public.user_log TO linuxtalks;


--
-- Name: SEQUENCE user_log_id_seq; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT USAGE ON SEQUENCE public.user_log_id_seq TO linuxtalks;


--
-- Name: TABLE user_remarks; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT ALL ON TABLE public.user_remarks TO linuxtalks;


--
-- Name: SEQUENCE user_remarks_id_seq; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT UPDATE ON SEQUENCE public.user_remarks_id_seq TO linuxtalks;


--
-- Name: TABLE user_settings; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT ALL ON TABLE public.user_settings TO linuxtalks;


--
-- Name: TABLE user_tags; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT ALL ON TABLE public.user_tags TO linuxtalks;


--
-- Name: TABLE users; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.users TO linuxtalks;


--
-- Name: SEQUENCE vote_id; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT UPDATE ON SEQUENCE public.vote_id TO linuxtalks;


--
-- Name: TABLE vote_users; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT SELECT,INSERT ON TABLE public.vote_users TO linuxtalks;


--
-- Name: SEQUENCE votes_id; Type: ACL; Schema: public; Owner: linuxtalks
--

GRANT UPDATE ON SEQUENCE public.votes_id TO linuxtalks;


--
-- PostgreSQL database dump complete
--


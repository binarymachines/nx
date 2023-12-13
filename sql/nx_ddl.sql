CREATE TABLE "dim_comments_bin" (
  "id" int4 NOT NULL,
  "value" varchar(8) NOT NULL,
  "label" varchar(16) NOT NULL,
  PRIMARY KEY ("id")
);

CREATE TABLE "dim_date_day" (
  "id" int4 NOT NULL,
  "value" int2,
  "label" varchar(4),
  PRIMARY KEY ("id")
);

CREATE TABLE "dim_date_month" (
  "id" int4 NOT NULL,
  "value" int2 NOT NULL,
  "label" varchar(16) NOT NULL,
  PRIMARY KEY ("id")
);

CREATE TABLE "dim_date_year" (
  "id" int4 NOT NULL,
  "value" varchar(255),
  "label" varchar(255),
  PRIMARY KEY ("id")
);

CREATE TABLE "dim_time_hour" (
  "id" int4 NOT NULL,
  "value" int2 NOT NULL,
  "label" varchar(2) NOT NULL,
  PRIMARY KEY ("id")
);

CREATE TABLE "dim_time_minute" (
  "id" int4 NOT NULL,
  "value" int2 NOT NULL,
  "label" varchar(2),
  PRIMARY KEY ("id")
);

CREATE TABLE "dim_upvotes_bin" (
  "id" int4 NOT NULL,
  "value" varchar(8) NOT NULL,
  "label" varchar(16) NOT NULL,
  PRIMARY KEY ("id")
);


CREATE TABLE "dim_xposts_bin" (
  "id" int4 NOT NULL,
  "value" varchar(8) NOT NULL,
  "label" varchar(16) NOT NULL,
  PRIMARY KEY ("id")
);

CREATE TABLE "fact_post" (
  "id" uuid NOT NULL,
  "mdb_object_id" varchar(64),
  "reddit_id" varchar(32),
  "subreddit_id" varchar(32),
  "subreddit_name" varchar(32),
  "author_name" varchar(32),
  "num_upvotes" int8,
  "num_comments" int8,
  "num_crossposts" int8,
  "score" int8,
  "event_timestamp" timestamp,
  "dim_date_month_id" int4,
  "dim_date_day_id" int4,
  "dim_date_year_id" int4,
  "dim_time_hour_id" int4,
  "dim_time_minute_id" int4,
  "dim_upvotes_bin_id" int4,
  "dim_comments_bin_id" int4,
  "dim_xposts_bin_id" int4,
  PRIMARY KEY ("id")
);



ALTER TABLE "fact_post" ADD CONSTRAINT "fk_fact_vote_dim_date_month_1" FOREIGN KEY ("dim_date_month_id") REFERENCES "dim_date_month" ("id");
ALTER TABLE "fact_post" ADD CONSTRAINT "fk_fact_vote_dim_date_day_1" FOREIGN KEY ("dim_date_day_id") REFERENCES "dim_date_day" ("id");
ALTER TABLE "fact_post" ADD CONSTRAINT "fk_fact_vote_dim_date_year_1" FOREIGN KEY ("dim_date_year_id") REFERENCES "dim_date_year" ("id");
ALTER TABLE "fact_post" ADD CONSTRAINT "fk_fact_post_dim_time_hour_1" FOREIGN KEY ("dim_time_hour_id") REFERENCES "dim_time_hour" ("id");
ALTER TABLE "fact_post" ADD CONSTRAINT "fk_fact_post_dim_time_minute_1" FOREIGN KEY ("dim_time_minute_id") REFERENCES "dim_time_minute" ("id");
ALTER TABLE "fact_post" ADD CONSTRAINT "fk_fact_post_dim_upvotes_bin_1" FOREIGN KEY ("dim_upvotes_bin_id") REFERENCES "dim_upvotes_bin" ("id");
ALTER TABLE "fact_post" ADD CONSTRAINT "fk_fact_post_dim_comments_bin_1" FOREIGN KEY ("dim_comments_bin_id") REFERENCES "dim_comments_bin" ("id");
ALTER TABLE "fact_post" ADD CONSTRAINT "fk_fact_post_dim_xposts_bin_1" FOREIGN KEY ("dim_xposts_bin_id") REFERENCES "dim_xposts_bin" ("id");


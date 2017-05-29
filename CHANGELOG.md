## 0.1.11 (2017-05-29)

Fix path problem when compressing data after a mongodb remote backup

## 0.1.10 (2017-04-25)

When extracting mongodb backup in /tmp, no permission to change utime on some system, so doing it in a sur directory

## 0.1.9 (2016-11-29)

Compatibility with pg_restore 9.1

## 0.1.8 (2016-10-03)

Better way to compare Mongoid version

## 0.1.7 (2016-08-15)

Mongorestore local, fix non standard port when using MONGO_URL

## 0.1.6 (2016-08-15)

Mongodump accept EXCLUDE_COLLECTIONS (names separated by ',') of not dumped collections

## 0.1.5 (2016-07-04)

Compatibility with Mongoid 5

## 0.1.4 (2016-02-02)

Features:

- Add `PG_DUMP_CMD` and `PG_RESTORE_CMD` vars

Bugfixes:

- Check app existence before using `scalingo` cli commands

## 0.1.3 (2016-01-21)

Features:

- Add `SSH_IDENTITY` env var

Bugfixes:

- Improve tunnel closing
- Improve Postgresql backup and restore

## 0.1.2 (2016-01-19)

Bugfixes:

- Improve error messages
- Check pg_restore version >= 9.4 for `-if-exists`

## 0.1.1 (2016-01-18)

Bugfixes:

- Postgresql drop db objects only `-if-exists`
- Abort tunnel when ssh key is encrypted
- Improve tunnel and create tmp dir
- Use ActiveRecord to get MySQL and PostgreSQL configs

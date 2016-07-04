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

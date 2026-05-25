// @ts-check

import { List, None, Ok, Error as GError } from "./gleam.mjs";
import { DB } from "https://deno.land/x/sqlite/mod.ts";
import * as $native from "./gdo/native.mjs";

/**
 * @param {string} path
 * @returns {Ok | GError}
 */
export function sqliteOpen(path) {
  try {
    return new Ok(new DB(path));
  } catch (error) {
    return sqliteError(error);
  }
}

/**
 * @param {any} connection
 * @returns {Ok | GError}
 */
export function sqliteClose(connection) {
  try {
    connection.close();
    return new Ok(undefined);
  } catch (error) {
    return sqliteError(error);
  }
}

/**
 * @param {string} sql
 * @param {any} connection
 * @returns {Ok | GError}
 */
export function sqliteExec(sql, connection) {
  try {
    connection.execute(sql);
    return new Ok(undefined);
  } catch (error) {
    return sqliteError(error);
  }
}

/**
 * @param {string} sql
 * @param {any} connection
 * @param {List} arguments_
 * @returns {Ok | GError}
 */
export function sqliteQuery(sql, connection, arguments_) {
  try {
    const rows = connection.query(sql, arguments_.toArray());
    return new Ok(List.fromArray(rows));
  } catch (error) {
    return sqliteError(error);
  }
}

function sqliteError(error) {
  return new GError(
    new $native.SqliteNativeError(
      Number.isInteger(error.code) ? error.code : -1,
      error.message ?? "Unknown SQLite error",
      Number.isInteger(error.offset) ? error.offset : -1,
    ),
  );
}

function mysqlUnsupported() {
  return new GError(
    new $native.MySqlNativeError(
      None,
      None,
      "MySQL is only supported on the Erlang target in the first pass.",
    ),
  );
}

export function mysqlOpen(
  _host,
  _port,
  _database,
  _username,
  _password,
  _tlsMode,
  _options,
) {
  return mysqlUnsupported();
}

export function mysqlClose(_connection) {
  return mysqlUnsupported();
}

export function mysqlExec(_sql, _connection, _arguments) {
  return mysqlUnsupported();
}

export function mysqlQuery(_sql, _connection, _arguments) {
  return mysqlUnsupported();
}

export function mysqlLastInsertId(_connection) {
  return mysqlUnsupported();
}

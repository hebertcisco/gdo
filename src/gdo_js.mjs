// @ts-check

import { List, Ok, Error as GError } from "./gleam.mjs";
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

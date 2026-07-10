import snowflake from 'snowflake-sdk';
import { loadConnection } from './config.js';

// Quiet the very chatty SDK logger; we surface our own errors.
snowflake.configure({ logLevel: 'ERROR' });

let connectionPromise = null;

function buildConnectionOptions(conn) {
  const opts = {
    account: conn.account,
    username: conn.user,
    role: conn.role,
    warehouse: conn.warehouse,
    database: conn.database,
    schema: conn.schema,
    // Keep results as native JS types where possible.
    jsTreatIntegerAsBigInt: false,
  };

  if (conn.authenticator && conn.authenticator.toUpperCase() === 'SNOWFLAKE_JWT') {
    opts.authenticator = 'SNOWFLAKE_JWT';
    opts.privateKeyPath = conn.privateKeyPath;
    if (conn.privateKeyPass) opts.privateKeyPass = conn.privateKeyPass;
  } else if (conn.password) {
    opts.password = conn.password;
  } else if (conn.authenticator) {
    opts.authenticator = conn.authenticator;
  }

  return opts;
}

/** Lazily create and cache a single connected Snowflake connection. */
export function getConnection() {
  if (connectionPromise) return connectionPromise;

  connectionPromise = new Promise((resolve, reject) => {
    const conn = loadConnection();
    const connection = snowflake.createConnection(buildConnectionOptions(conn));
    connection.connect((err, c) => {
      if (err) {
        connectionPromise = null; // allow retry on next request
        reject(err);
      } else {
        resolve(c);
      }
    });
  });

  return connectionPromise;
}

/** Run a SQL statement and resolve to an array of row objects. */
export async function query(sqlText, binds = []) {
  const connection = await getConnection();
  return new Promise((resolve, reject) => {
    connection.execute({
      sqlText,
      binds,
      complete: (err, _stmt, rows) => (err ? reject(err) : resolve(rows || [])),
    });
  });
}

/** Lightweight connection probe used by /api/health. */
export async function ping() {
  const rows = await query(
    'select current_account() as account, current_user() as user, current_role() as role, current_warehouse() as warehouse'
  );
  return rows[0] || null;
}
